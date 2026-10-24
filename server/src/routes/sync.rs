use axum::{extract::State, http::StatusCode, response::IntoResponse, Json};
use chrono::Utc;
use tracing::info;

use crate::{
    models::{ApiResponse, SyncBatchRequest, SyncBatchResponse},
    AppState,
};

pub async fn batch_sync(
    State(state): State<AppState>,
    Json(payload): Json<SyncBatchRequest>,
) -> impl IntoResponse {
    let mut synced_notes = 0;
    let mut synced_folders = 0;

    // Sync folders
    for folder in payload.folders {
        let _ = state.db.create_folder(&folder.name, &folder.icon, &folder.color);
        synced_folders += 1;
    }

    // Sync notes
    for note in payload.notes {
        match state.db.get_note_by_id(&note.id) {
            Ok(existing) => {
                // Keep the one with newer updated_at
                if note.updated_at > existing.updated_at {
                    let _ = state.db.update_note(
                        &note.id,
                        Some(&note.folder_id),
                        Some(&note.title),
                        Some(&note.body),
                        Some(note.is_pinned),
                        Some(note.is_deleted),
                        note.b2_key.as_deref(),
                        note.b2_url.as_deref(),
                    );
                }
            }
            Err(_) => {
                let _ = state.db.create_note(
                    Some(note.id),
                    &note.folder_id,
                    &note.title,
                    &note.body,
                    note.is_pinned,
                );
            }
        }
        synced_notes += 1;
    }

    info!(
        synced_notes = synced_notes,
        synced_folders = synced_folders,
        "Batch sync completed"
    );

    (
        StatusCode::OK,
        Json(ApiResponse::success(SyncBatchResponse {
            synced_notes_count: synced_notes,
            synced_folders_count: synced_folders,
            server_time: Utc::now(),
        })),
    )
}
