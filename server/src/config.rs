use std::env;
use std::fs;
use std::path::Path;

#[derive(Clone, Debug)]
pub struct Config {
    pub port: u16,
    pub b2_account_id: String,
    pub b2_application_key_id: String,
    pub b2_application_key: String,
    pub b2_bucket_name: String,
    pub b2_bucket_id: String,
    pub cdn_base_url: String,
    pub db_path: String,
}

impl Config {
    pub fn load() -> Self {
        // Try reading /root/.b2.env or /root/.b2/credentials if present
        Self::load_env_file("/root/.b2.env");
        Self::load_env_file("/root/.b2/credentials");

        let port = env::var("PORT")
            .unwrap_or_else(|_| "8085".to_string())
            .parse::<u16>()
            .unwrap_or(8085);

        let b2_account_id = env::var("B2_ACCOUNT_ID")
            .unwrap_or_else(|_| "ffcd38a3a514".to_string());

        let b2_application_key_id = env::var("B2_APPLICATION_KEY_ID")
            .or_else(|_| env::var("KEY_ID"))
            .unwrap_or_else(|_| "003ffcd38a3a514000000000f".to_string());

        let b2_application_key = env::var("B2_APPLICATION_KEY")
            .or_else(|_| env::var("APP_KEY"))
            .unwrap_or_else(|_| "K0038jWSTA9PlX0GyZ9KRcsRBLp2ycs".to_string());

        let b2_bucket_name = env::var("B2_DEFAULT_BUCKET")
            .or_else(|_| env::var("DEFAULT_BUCKET"))
            .unwrap_or_else(|_| "kreatix-agy".to_string());

        let b2_bucket_id = env::var("DEFAULT_BUCKET_ID")
            .unwrap_or_else(|_| "afcfac5d33886a03aa150114".to_string());

        let cdn_base_url = env::var("CDN_BASE_URL")
            .unwrap_or_else(|_| "https://cdn.kreatix.dev/file".to_string());

        let db_path = env::var("DATABASE_PATH")
            .unwrap_or_else(|_| "notes.db".to_string());

        Config {
            port,
            b2_account_id,
            b2_application_key_id,
            b2_application_key,
            b2_bucket_name,
            b2_bucket_id,
            cdn_base_url,
            db_path,
        }
    }

    fn load_env_file<P: AsRef<Path>>(path: P) {
        if let Ok(contents) = fs::read_to_string(path) {
            for line in contents.lines() {
                let line = line.trim();
                if line.is_empty() || line.starts_with('#') {
                    continue;
                }
                let line = line.trim_start_matches("export ").trim();
                if let Some((key, value)) = line.split_once('=') {
                    let key = key.trim();
                    let value = value.trim().trim_matches('"').trim_matches('\'');
                    if env::var(key).is_err() {
                        env::set_var(key, value);
                    }
                }
            }
        }
    }
}
