use axum::{
    extract::{Multipart, Path, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use std::path::Path as StdPath;
use tracing::{error, info};
use uuid::Uuid;

use crate::{
    models::{ApiResponse, Attachment},
    AppState,
};

pub async fn upload_attachment(
    State(state): State<AppState>,
    Path(note_id): Path<String>,
    mut multipart: Multipart,
) -> impl IntoResponse {
    // Validate note exists
    if let Err(e) = state.db.get_note_by_id(&note_id) {
        return (
            StatusCode::NOT_FOUND,
            Json(ApiResponse::error(format!("Note not found: {}", e))),
        );
    }

    let mut saved_attachment: Option<Attachment> = None;

    while let Ok(Some(field)) = multipart.next_field().await {
        let file_name = field
            .file_name()
            .map(|s| s.to_string())
            .unwrap_or_else(|| format!("attachment_{}.bin", Uuid::new_v4()));

        let content_type = field
            .content_type()
            .map(|s| s.to_string())
            .unwrap_or_else(|| {
                mime_guess::from_path(&file_name)
                    .first_or_octet_stream()
                    .to_string()
            });

        match field.bytes().await {
            Ok(bytes) => {
                let size = bytes.len() as i64;
                let extension = StdPath::new(&file_name)
                    .extension()
                    .and_then(|s| s.to_str())
                    .unwrap_or("bin");
                let unique_id = Uuid::new_v4().to_string();
                let remote_key = format!("attachments/{}/{}.{}", note_id, unique_id, extension);

                info!(
                    note_id = %note_id,
                    remote_key = %remote_key,
                    file_name = %file_name,
                    size = size,
                    "Uploading attachment to Backblaze B2"
                );

                match state
                    .b2
                    .upload_file(&remote_key, bytes.to_vec(), &content_type)
                    .await
                {
                    Ok(cdn_url) => {
                        match state.db.add_attachment(
                            &note_id,
                            &file_name,
                            &content_type,
                            size,
                            &remote_key,
                            &cdn_url,
                        ) {
                            Ok(att) => {
                                saved_attachment = Some(att);
                                break;
                            }
                            Err(e) => {
                                error!("Failed to save attachment metadata: {}", e);
                                return (
                                    StatusCode::INTERNAL_SERVER_ERROR,
                                    Json(ApiResponse::error(e.to_string())),
                                );
                            }
                        }
                    }
                    Err(e) => {
                        error!("Failed to upload to B2: {}", e);
                        return (
                            StatusCode::INTERNAL_SERVER_ERROR,
                            Json(ApiResponse::error(format!("B2 upload error: {}", e))),
                        );
                    }
                }
            }
            Err(e) => {
                error!("Failed to read multipart stream: {}", e);
                return (
                    StatusCode::BAD_REQUEST,
                    Json(ApiResponse::error(e.to_string())),
                );
            }
        }
    }

    if let Some(att) = saved_attachment {
        (StatusCode::CREATED, Json(ApiResponse::success(att)))
    } else {
        (
            StatusCode::BAD_REQUEST,
            Json(ApiResponse::error("No file provided in form-data")),
        )
    }
}
