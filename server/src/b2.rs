use anyhow::{anyhow, Context, Result};
use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION, CONTENT_LENGTH, CONTENT_TYPE};
use serde::{Deserialize, Serialize};
use sha1::{Digest, Sha1};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::info;

use crate::config::Config;

#[derive(Debug, Clone, Deserialize)]
struct B2AuthResponse {
    #[serde(rename = "authorizationToken")]
    authorization_token: String,
    #[serde(rename = "apiInfo")]
    api_info: B2ApiInfo,
}

#[derive(Debug, Clone, Deserialize)]
struct B2ApiInfo {
    #[serde(rename = "storageApi")]
    storage_api: B2StorageApi,
}

#[derive(Debug, Clone, Deserialize)]
struct B2StorageApi {
    #[serde(rename = "apiUrl")]
    api_url: String,
    #[serde(rename = "downloadUrl")]
    download_url: String,
}

#[derive(Debug, Clone, Deserialize)]
struct B2UploadUrlResponse {
    #[serde(rename = "uploadUrl")]
    upload_url: String,
    #[serde(rename = "authorizationToken")]
    authorization_token: String,
}

#[derive(Debug, Clone, Deserialize)]
#[allow(dead_code)]
struct B2UploadFileResponse {
    #[serde(rename = "fileId")]
    file_id: String,
    #[serde(rename = "fileName")]
    file_name: String,
    #[serde(rename = "contentLength")]
    content_length: u64,
}

#[derive(Clone)]
#[allow(dead_code)]
struct CachedAuth {
    token: String,
    api_url: String,
    download_url: String,
    fetched_at: std::time::Instant,
}

#[derive(Clone)]
pub struct B2Client {
    config: Config,
    client: reqwest::Client,
    cached_auth: Arc<RwLock<Option<CachedAuth>>>,
}

impl B2Client {
    pub fn new(config: Config) -> Self {
        let client = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(60))
            .build()
            .unwrap_or_default();

        Self {
            config,
            client,
            cached_auth: Arc::new(RwLock::new(None)),
        }
    }

    async fn get_auth(&self) -> Result<CachedAuth> {
        // Read lock first
        {
            let read_guard = self.cached_auth.read().await;
            if let Some(cached) = &*read_guard {
                // Tokens valid for up to 24h, refresh if older than 4 hours
                if cached.fetched_at.elapsed().as_secs() < 4 * 3600 {
                    return Ok(cached.clone());
                }
            }
        }

        // Need new token
        let mut write_guard = self.cached_auth.write().await;
        // Double check
        if let Some(cached) = &*write_guard {
            if cached.fetched_at.elapsed().as_secs() < 4 * 3600 {
                return Ok(cached.clone());
            }
        }

        info!("Authorizing with Backblaze B2 API...");
        let resp = self
            .client
            .get("https://api.backblazeb2.com/b2api/v3/b2_authorize_account")
            .basic_auth(
                &self.config.b2_application_key_id,
                Some(&self.config.b2_application_key),
            )
            .send()
            .await
            .context("Failed to contact B2 authorize account API")?;

        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            return Err(anyhow!("B2 authorize error {}: {}", status, body));
        }

        let auth_data: B2AuthResponse = resp
            .json()
            .await
            .context("Failed to parse B2 authorize response")?;

        let cached = CachedAuth {
            token: auth_data.authorization_token,
            api_url: auth_data.api_info.storage_api.api_url,
            download_url: auth_data.api_info.storage_api.download_url,
            fetched_at: std::time::Instant::now(),
        };

        *write_guard = Some(cached.clone());
        info!("B2 account authorized successfully");
        Ok(cached)
    }

    pub async fn upload_file(
        &self,
        remote_path: &str,
        data: Vec<u8>,
        mime_type: &str,
    ) -> Result<String> {
        let auth = self.get_auth().await?;

        // 1. Get upload url
        let get_upload_endpoint = format!("{}/b2api/v3/b2_get_upload_url", auth.api_url);
        #[derive(Serialize)]
        struct GetUploadUrlPayload<'a> {
            #[serde(rename = "bucketId")]
            bucket_id: &'a str,
        }

        let upload_info_resp = self
            .client
            .post(&get_upload_endpoint)
            .header(AUTHORIZATION, &auth.token)
            .json(&GetUploadUrlPayload {
                bucket_id: &self.config.b2_bucket_id,
            })
            .send()
            .await
            .context("Failed to request upload URL from B2")?;

        if !upload_info_resp.status().is_success() {
            let status = upload_info_resp.status();
            let body = upload_info_resp.text().await.unwrap_or_default();
            return Err(anyhow!("B2 get_upload_url failed {}: {}", status, body));
        }

        let upload_info: B2UploadUrlResponse = upload_info_resp
            .json()
            .await
            .context("Failed to parse B2 upload URL response")?;

        // 2. Compute SHA1
        let mut hasher = Sha1::new();
        hasher.update(&data);
        let sha1_hex = hex::encode(hasher.finalize());

        // 3. Upload to B2
        let file_len = data.len();
        // Percent-encode filename for header if necessary
        let encoded_remote_path = urlencoding::encode(remote_path).to_string();

        let mut headers = HeaderMap::new();
        headers.insert(
            AUTHORIZATION,
            HeaderValue::from_str(&upload_info.authorization_token)?,
        );
        headers.insert(
            "X-Bz-File-Name",
            HeaderValue::from_str(&encoded_remote_path)?,
        );
        headers.insert(CONTENT_TYPE, HeaderValue::from_str(mime_type)?);
        headers.insert(
            CONTENT_LENGTH,
            HeaderValue::from_str(&file_len.to_string())?,
        );
        headers.insert("X-Bz-Content-Sha1", HeaderValue::from_str(&sha1_hex)?);

        let upload_resp = self
            .client
            .post(&upload_info.upload_url)
            .headers(headers)
            .body(data)
            .send()
            .await
            .context("Failed to stream upload payload to B2")?;

        if !upload_resp.status().is_success() {
            let status = upload_resp.status();
            let body = upload_resp.text().await.unwrap_or_default();
            return Err(anyhow!("B2 upload payload failed {}: {}", status, body));
        }

        let upload_result: B2UploadFileResponse = upload_resp
            .json()
            .await
            .context("Failed to parse B2 upload response")?;

        info!(
            file_id = %upload_result.file_id,
            remote_path = %remote_path,
            "Successfully uploaded file to B2"
        );

        // Always format as https://cdn.kreatix.dev/file/<bucket>/<path>
        let cdn_url = format!(
            "{}/{}/{}",
            self.config.cdn_base_url.trim_end_matches('/'),
            self.config.b2_bucket_name,
            remote_path.trim_start_matches('/')
        );

        Ok(cdn_url)
    }

    pub async fn backup_note_snapshot(
        &self,
        note_id: &str,
        note_json: &[u8],
    ) -> Result<String> {
        let remote_key = format!("notes/{}.json", note_id);
        self.upload_file(&remote_key, note_json.to_vec(), "application/json")
            .await
    }
}
