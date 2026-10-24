mod b2;
mod config;
mod db;
mod models;
mod routes;

use axum::{
    extract::State,
    http::{header, Method, StatusCode},
    response::{Html, IntoResponse},
    routing::{delete, get, post, put},
    Json, Router,
};
use chrono::Utc;
use std::net::SocketAddr;
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;
use tracing::info;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use crate::{
    b2::B2Client,
    config::Config,
    db::Database,
    models::{ApiResponse, HealthStatus},
};

#[derive(Clone)]
pub struct AppState {
    pub config: Config,
    pub db: Database,
    pub b2: B2Client,
}

async fn health_check(State(state): State<AppState>) -> impl IntoResponse {
    let health = HealthStatus {
        status: "ok".to_string(),
        version: env!("CARGO_PKG_VERSION").to_string(),
        b2_bucket: state.config.b2_bucket_name.clone(),
        cdn_base_url: state.config.cdn_base_url.clone(),
        time: Utc::now(),
    };
    (StatusCode::OK, Json(ApiResponse::success(health)))
}

async fn index_dashboard(State(state): State<AppState>) -> impl IntoResponse {
    let folders_count = state.db.get_folders().map(|f| f.len()).unwrap_or(0);
    let notes_count = state
        .db
        .get_notes_summaries(None, None, false, false)
        .map(|n| n.len())
        .unwrap_or(0);

    let html = format!(
        r#"<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NotesCloud - Backblaze B2 Storage</title>
    <style>
        :root {{
            --bg: #1c1c1e;
            --card-bg: #2c2c2e;
            --accent: #E8A738;
            --text: #f2f2f7;
            --text-secondary: #8e8e93;
            --border: #38383a;
        }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", Helvetica, Arial, sans-serif;
            background-color: var(--bg);
            color: var(--text);
            margin: 0;
            padding: 30px 20px;
            display: flex;
            justify-content: center;
        }}
        .container {{
            max-width: 720px;
            width: 100%;
        }}
        .header {{
            display: flex;
            align-items: center;
            gap: 16px;
            margin-bottom: 28px;
        }}
        .icon-badge {{
            width: 52px;
            height: 52px;
            border-radius: 14px;
            background: linear-gradient(135deg, #FAD961 0%, #F76B1C 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 26px;
            box-shadow: 0 4px 14px rgba(247, 107, 28, 0.35);
        }}
        h1 {{
            margin: 0;
            font-size: 28px;
            font-weight: 700;
        }}
        .subtitle {{
            margin: 4px 0 0 0;
            color: var(--text-secondary);
            font-size: 15px;
        }}
        .grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }}
        .card {{
            background: var(--card-bg);
            border-radius: 14px;
            padding: 18px;
            border: 1px solid var(--border);
        }}
        .stat-value {{
            font-size: 32px;
            font-weight: 700;
            color: var(--accent);
            margin-bottom: 4px;
        }}
        .stat-label {{
            font-size: 14px;
            color: var(--text-secondary);
            font-weight: 500;
        }}
        .endpoints {{
            background: var(--card-bg);
            border-radius: 14px;
            padding: 20px;
            border: 1px solid var(--border);
        }}
        h2 {{
            margin-top: 0;
            font-size: 18px;
        }}
        .endpoint-row {{
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 10px 0;
            border-bottom: 1px solid var(--border);
            font-family: ui-monospace, Menlo, Monaco, monospace;
            font-size: 13px;
        }}
        .endpoint-row:last-child {{
            border-bottom: none;
        }}
        .method {{
            padding: 2px 8px;
            border-radius: 6px;
            font-weight: 700;
            font-size: 11px;
        }}
        .get {{ background: rgba(52, 199, 89, 0.2); color: #34c759; }}
        .post {{ background: rgba(0, 122, 255, 0.2); color: #007aff; }}
        .put {{ background: rgba(255, 149, 0, 0.2); color: #ff9500; }}
        .delete {{ background: rgba(255, 69, 58, 0.2); color: #ff453a; }}
        .cdn-badge {{
            display: inline-block;
            background: rgba(232, 167, 56, 0.15);
            color: #E8A738;
            padding: 4px 10px;
            border-radius: 6px;
            font-size: 12px;
            margin-top: 8px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="icon-badge">
                <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
                    <polyline points="14 2 14 8 20 8"></polyline>
                    <line x1="16" y1="13" x2="8" y2="13"></line>
                    <line x1="16" y1="17" x2="8" y2="17"></line>
                    <polyline points="10 9 9 9 8 9"></polyline>
                </svg>
            </div>
            <div>
                <h1>NotesCloud Server</h1>
                <div class="subtitle">Self-Hosted Native iOS Notes API | Backblaze B2 & Cloudflare CDN</div>
            </div>
        </div>

        <div class="grid">
            <div class="card">
                <div class="stat-value">{}</div>
                <div class="stat-label">Folders</div>
            </div>
            <div class="card">
                <div class="stat-value">{}</div>
                <div class="stat-label">Active Notes</div>
            </div>
            <div class="card">
                <div class="stat-value">Online</div>
                <div class="stat-label">B2 Cloud Storage</div>
                <div class="cdn-badge">Bucket: {}</div>
            </div>
        </div>

        <div class="endpoints">
            <h2>REST API Endpoints</h2>
            <div class="endpoint-row"><span class="method get">GET</span> <span>/api/health</span> &mdash; Status & B2 health</div>
            <div class="endpoint-row"><span class="method get">GET</span> <span>/api/folders</span> &mdash; List all folders with counts</div>
            <div class="endpoint-row"><span class="method post">POST</span> <span>/api/folders</span> &mdash; Create folder</div>
            <div class="endpoint-row"><span class="method get">GET</span> <span>/api/notes?folder_id=...&search=...</span> &mdash; Notes list</div>
            <div class="endpoint-row"><span class="method post">POST</span> <span>/api/notes</span> &mdash; Create note (syncs to B2)</div>
            <div class="endpoint-row"><span class="method put">PUT</span> <span>/api/notes/:id</span> &mdash; Update note</div>
            <div class="endpoint-row"><span class="method delete">DELETE</span> <span>/api/notes/:id</span> &mdash; Move to trash / delete</div>
            <div class="endpoint-row"><span class="method post">POST</span> <span>/api/notes/:id/pin</span> &mdash; Toggle pinned state</div>
            <div class="endpoint-row"><span class="method post">POST</span> <span>/api/notes/:id/attachments</span> &mdash; Upload image/drawing to B2</div>
            <div class="endpoint-row"><span class="method post">POST</span> <span>/api/sync</span> &mdash; Batch offline reconciliation</div>
        </div>
    </div>
</body>
</html>"#,
        folders_count, notes_count, state.config.b2_bucket_name
    );

    Html(html)
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,notes_server=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    let config = Config::load();
    info!("Starting NotesCloud Server on port {}", config.port);
    info!("B2 Bucket: {}", config.b2_bucket_name);
    info!("CDN Base URL: {}", config.cdn_base_url);

    let db = Database::new(&config.db_path)?;
    let b2 = B2Client::new(config.clone());

    let state = AppState { config: config.clone(), db, b2 };

    let cors = CorsLayer::new()
        .allow_origin(tower_http::cors::Any)
        .allow_methods([
            Method::GET,
            Method::POST,
            Method::PUT,
            Method::DELETE,
            Method::OPTIONS,
        ])
        .allow_headers([
            header::CONTENT_TYPE,
            header::AUTHORIZATION,
            header::ACCEPT,
            header::HeaderName::from_static("x-requested-with"),
        ]);

    let app = Router::new()
        .route("/", get(index_dashboard))
        .route("/api/health", get(health_check))
        // Folders
        .route("/api/folders", get(routes::folders::list_folders))
        .route("/api/folders", post(routes::folders::create_folder))
        .route("/api/folders/:id", get(routes::folders::get_folder))
        .route("/api/folders/:id", put(routes::folders::update_folder))
        .route("/api/folders/:id", delete(routes::folders::delete_folder))
        // Notes
        .route("/api/notes", get(routes::notes::list_notes))
        .route("/api/notes", post(routes::notes::create_note))
        .route("/api/notes/:id", get(routes::notes::get_note))
        .route("/api/notes/:id", put(routes::notes::update_note))
        .route("/api/notes/:id", delete(routes::notes::delete_note))
        .route("/api/notes/:id/pin", post(routes::notes::toggle_pin))
        // Attachments
        .route(
            "/api/notes/:id/attachments",
            post(routes::attachments::upload_attachment),
        )
        // Sync
        .route("/api/sync", post(routes::sync::batch_sync))
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], config.port));
    info!("Server listening on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
