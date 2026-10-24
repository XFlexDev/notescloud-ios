use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use tracing::error;

use crate::{
    models::{ApiResponse, CreateFolderRequest, UpdateFolderRequest},
    AppState,
};

pub async fn list_folders(State(state): State<AppState>) -> impl IntoResponse {
    match state.db.get_folders() {
        Ok(folders) => (StatusCode::OK, Json(ApiResponse::success(folders))),
        Err(e) => {
            error!("Failed to fetch folders: {}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ApiResponse::error(e.to_string())),
            )
        }
    }
}

pub async fn get_folder(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> impl IntoResponse {
    match state.db.get_folder_by_id(&id) {
        Ok(folder) => (StatusCode::OK, Json(ApiResponse::success(folder))),
        Err(e) => (
            StatusCode::NOT_FOUND,
            Json(ApiResponse::error(e.to_string())),
        ),
    }
}

pub async fn create_folder(
    State(state): State<AppState>,
    Json(payload): Json<CreateFolderRequest>,
) -> impl IntoResponse {
    let icon = payload.icon.as_deref().unwrap_or("folder");
    let color = payload.color.as_deref().unwrap_or("#E8A738");

    match state.db.create_folder(&payload.name, icon, color) {
        Ok(folder) => (StatusCode::CREATED, Json(ApiResponse::success(folder))),
        Err(e) => {
            error!("Failed to create folder: {}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ApiResponse::error(e.to_string())),
            )
        }
    }
}

pub async fn update_folder(
    State(state): State<AppState>,
    Path(id): Path<String>,
    Json(payload): Json<UpdateFolderRequest>,
) -> impl IntoResponse {
    match state.db.update_folder(
        &id,
        payload.name.as_deref(),
        payload.icon.as_deref(),
        payload.color.as_deref(),
    ) {
        Ok(folder) => (StatusCode::OK, Json(ApiResponse::success(folder))),
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiResponse::error(e.to_string())),
        ),
    }
}

pub async fn delete_folder(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> impl IntoResponse {
    match state.db.delete_folder(&id) {
        Ok(_) => (StatusCode::OK, Json(ApiResponse::success(true))),
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiResponse::error(e.to_string())),
        ),
    }
}
