use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use serde::Deserialize;
use tracing::{error, info};

use crate::{
    models::{ApiResponse, CreateNoteRequest, UpdateNoteRequest},
    AppState,
};

#[derive(Debug, Deserialize)]
pub struct NotesQuery {
    pub folder_id: Option<String>,
    pub search: Option<String>,
    pub pinned: Option<bool>,
    pub deleted: Option<bool>,
}

pub async fn list_notes(
    State(state): State<AppState>,
    Query(query): Query<NotesQuery>,
) -> impl IntoResponse {
    let pinned_only = query.pinned.unwrap_or(false);
    let include_deleted = query.deleted.unwrap_or(false);

    match state.db.get_notes_summaries(
        query.folder_id.as_deref(),
        query.search.as_deref(),
        pinned_only,
        include_deleted,
    ) {
        Ok(notes) => (StatusCode::OK, Json(ApiResponse::success(notes))),
        Err(e) => {
            error!("Failed to fetch notes: {}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ApiResponse::error(e.to_string())),
            )
        }
    }
}

pub async fn get_note(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> impl IntoResponse {
    match state.db.get_note_by_id(&id) {
        Ok(note) => (StatusCode::OK, Json(ApiResponse::success(note))),
        Err(e) => (
            StatusCode::NOT_FOUND,
            Json(ApiResponse::error(e.to_string())),
        ),
    }
}

pub async fn create_note(
    State(state): State<AppState>,
    Json(payload): Json<CreateNoteRequest>,
) -> impl IntoResponse {
    let folder_id = payload
        .folder_id
        .as_deref()
        .unwrap_or("folder-notes-default");
    let title = payload.title.as_deref().unwrap_or("");
    let body = payload.body.as_deref().unwrap_or("");
    let is_pinned = payload.is_pinned.unwrap_or(false);

    match state
        .db
        .create_note(payload.id, folder_id, title, body, is_pinned)
    {
        Ok(note) => {
            // Asynchronously sync note JSON snapshot to B2
            let b2 = state.b2.clone();
            let db = state.db.clone();
            let note_clone = note.clone();
            tokio::spawn(async move {
                if let Ok(json_bytes) = serde_json::to_vec_pretty(&note_clone) {
                    match b2.backup_note_snapshot(&note_clone.id, &json_bytes).await {
                        Ok(url) => {
                            let key = format!("notes/{}.json", note_clone.id);
                            let _ = db.update_note(
                                &note_clone.id,
                                None,
                                None,
                                None,
                                None,
                                None,
                                Some(&key),
                                Some(&url),
                            );
                            info!(note_id = %note_clone.id, url = %url, "Note backed up to B2");
                        }
                        Err(e) => {
                            error!(note_id = %note_clone.id, error = %e, "Failed to backup note to B2");
                        }
                    }
                }
            });

            (StatusCode::CREATED, Json(ApiResponse::success(note)))
        }
        Err(e) => {
            error!("Failed to create note: {}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ApiResponse::error(e.to_string())),
            )
        }
    }
}

pub async fn update_note(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(payload): Json<UpdateNoteRequest>,
) -> impl IntoResponse {
    match state.db.update_note(
        &id,
        payload.folder_id.as_deref(),
        payload.title.as_deref(),
        payload.body.as_deref(),
        payload.is_pinned,
        payload.is_deleted,
        None,
        None,
    ) {
        Ok(note) => {
            // Asynchronously sync updated snapshot to B2
            let b2 = state.b2.clone();
            let db = state.db.clone();
            let note_clone = note.clone();
            tokio::spawn(async move {
                if let Ok(json_bytes) = serde_json::to_vec_pretty(&note_clone) {
                    match b2.backup_note_snapshot(&note_clone.id, &json_bytes).await {
                        Ok(url) => {
                            let key = format!("notes/{}.json", note_clone.id);
                            let _ = db.update_note(
                                &note_clone.id,
                                None,
                                None,
                                None,
                                None,
                                None,
                                Some(&key),
                                Some(&url),
                            );
                        }
                        Err(e) => {
                            error!(note_id = %note_clone.id, error = %e, "Failed to sync note to B2");
                        }
                    }
                }
            });

            (StatusCode::OK, Json(ApiResponse::success(note)))
        }
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiResponse::error(e.to_string())),
        ),
    }
}

pub async fn delete_note(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Query(params): Query<std::collections::HashMap<String, String>>,
) -> impl IntoResponse {
    let permanent = params
        .get("permanent")
        .map(|v| v == "true" || v == "1")
        .unwrap_or(false);

    match state.db.delete_note(&id, permanent) {
        Ok(_) => (StatusCode::OK, Json(ApiResponse::success(true))),
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiResponse::error(e.to_string())),
        ),
    }
}

pub async fn toggle_pin(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> impl IntoResponse {
    match state.db.toggle_pin(&id) {
        Ok(pinned) => (StatusCode::OK, Json(ApiResponse::success(pinned))),
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiResponse::error(e.to_string())),
        ),
    }
}
