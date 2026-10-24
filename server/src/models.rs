use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Folder {
    pub id: String,
    pub name: String,
    pub icon: String,
    pub color: String,
    pub order_index: i32,
    pub note_count: i64,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct CreateFolderRequest {
    pub name: String,
    pub icon: Option<String>,
    pub color: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct UpdateFolderRequest {
    pub name: Option<String>,
    pub icon: Option<String>,
    pub color: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Attachment {
    pub id: String,
    pub note_id: String,
    pub file_name: String,
    pub mime_type: String,
    pub byte_size: i64,
    pub b2_key: String,
    pub cdn_url: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Note {
    pub id: String,
    pub folder_id: String,
    pub title: String,
    pub body: String,
    pub is_pinned: bool,
    pub is_deleted: bool,
    pub b2_key: Option<String>,
    pub b2_url: Option<String>,
    pub attachments: Vec<Attachment>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NoteSummary {
    pub id: String,
    pub folder_id: String,
    pub title: String,
    pub snippet: String,
    pub is_pinned: bool,
    pub is_deleted: bool,
    pub attachment_count: i64,
    pub preview_image_url: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct CreateNoteRequest {
    pub id: Option<String>,
    pub folder_id: Option<String>,
    pub title: Option<String>,
    pub body: Option<String>,
    pub is_pinned: Option<bool>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct UpdateNoteRequest {
    pub folder_id: Option<String>,
    pub title: Option<String>,
    pub body: Option<String>,
    pub is_pinned: Option<bool>,
    pub is_deleted: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiResponse<T> {
    pub success: bool,
    pub data: Option<T>,
    pub error: Option<String>,
}

impl<T> ApiResponse<T> {
    pub fn success(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
        }
    }

    pub fn error(msg: impl Into<String>) -> Self {
        Self {
            success: false,
            data: None,
            error: Some(msg.into()),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HealthStatus {
    pub status: String,
    pub version: String,
    pub b2_bucket: String,
    pub cdn_base_url: String,
    pub time: DateTime<Utc>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct SyncBatchRequest {
    pub notes: Vec<Note>,
    pub folders: Vec<Folder>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncBatchResponse {
    pub synced_notes_count: usize,
    pub synced_folders_count: usize,
    pub server_time: DateTime<Utc>,
}
