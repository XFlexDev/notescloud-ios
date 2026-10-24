use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use rusqlite::{params, Connection};
use std::sync::{Arc, Mutex};
use uuid::Uuid;

use crate::models::{Attachment, Folder, Note, NoteSummary};

#[derive(Clone)]
pub struct Database {
    conn: Arc<Mutex<Connection>>,
}

impl Database {
    pub fn new(path: &str) -> Result<Self> {
        let conn = Connection::open(path)
            .context(format!("Failed to open SQLite database at {}", path))?;

        let db = Self {
            conn: Arc::new(Mutex::new(conn)),
        };

        db.init_schema()?;
        Ok(db)
    }

    fn init_schema(&self) -> Result<()> {
        let conn = self.conn.lock().unwrap();

        conn.execute_batch(
            r#"
            PRAGMA journal_mode = WAL;
            PRAGMA foreign_keys = ON;

            CREATE TABLE IF NOT EXISTS folders (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                icon TEXT NOT NULL DEFAULT 'folder',
                color TEXT NOT NULL DEFAULT '#E8A738',
                order_index INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS notes (
                id TEXT PRIMARY KEY,
                folder_id TEXT NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
                title TEXT NOT NULL DEFAULT '',
                body TEXT NOT NULL DEFAULT '',
                is_pinned INTEGER NOT NULL DEFAULT 0,
                is_deleted INTEGER NOT NULL DEFAULT 0,
                b2_key TEXT,
                b2_url TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_notes_folder ON notes(folder_id);
            CREATE INDEX IF NOT EXISTS idx_notes_updated ON notes(updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_notes_pinned ON notes(is_pinned);

            CREATE TABLE IF NOT EXISTS attachments (
                id TEXT PRIMARY KEY,
                note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
                file_name TEXT NOT NULL,
                mime_type TEXT NOT NULL,
                byte_size INTEGER NOT NULL,
                b2_key TEXT NOT NULL,
                cdn_url TEXT NOT NULL,
                created_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_attachments_note ON attachments(note_id);
            "#,
        )?;

        // Seed default folders if empty
        let count: i64 = conn.query_row("SELECT COUNT(*) FROM folders", [], |row| row.get(0))?;
        if count == 0 {
            let now = Utc::now().to_rfc3339();
            let mut stmt = conn.prepare(
                "INSERT INTO folders (id, name, icon, color, order_index, created_at, updated_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)"
            )?;

            stmt.execute(params![
                "folder-notes-default",
                "Notes",
                "folder",
                "#E8A738",
                0,
                now,
                now
            ])?;

            stmt.execute(params![
                "folder-personal",
                "Personal",
                "person.fill",
                "#5856D6",
                1,
                now,
                now
            ])?;

            stmt.execute(params![
                "folder-work",
                "Work",
                "briefcase.fill",
                "#007AFF",
                2,
                now,
                now
            ])?;

            stmt.execute(params![
                "folder-ideas",
                "Ideas",
                "lightbulb.fill",
                "#FF9500",
                3,
                now,
                now
            ])?;

            // Add a welcome note
            let note_id = Uuid::new_v4().to_string();
            let welcome_title = "Welcome to NotesCloud";
            let welcome_body = "Welcome to your native iOS Notes app powered by Backblaze B2!\n\n\
                Features:\n\
                - Authentic iOS Notes look, feel, and paper aesthetic\n\
                - Instant synchronization with your self-hosted Rust server\n\
                - Backblaze B2 cloud storage integration for notes and media\n\
                - Fast CDN delivery via https://cdn.kreatix.dev\n\
                - Rich text, interactive checklists, drawings & photo attachments\n\
                - Seamless offline support with automatic background sync\n\n\
                Enjoy taking notes!";

            conn.execute(
                "INSERT INTO notes (id, folder_id, title, body, is_pinned, is_deleted, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, 1, 0, ?5, ?6)",
                params![note_id, "folder-notes-default", welcome_title, welcome_body, now, now],
            )?;
        }

        Ok(())
    }

    pub fn get_folders(&self) -> Result<Vec<Folder>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            r#"
            SELECT f.id, f.name, f.icon, f.color, f.order_index,
                   (SELECT COUNT(*) FROM notes n WHERE n.folder_id = f.id AND n.is_deleted = 0) as note_count,
                   f.created_at, f.updated_at
            FROM folders f
            ORDER BY f.order_index ASC, f.name ASC
            "#,
        )?;

        let rows = stmt.query_map([], |row| {
            let created_str: String = row.get(6)?;
            let updated_str: String = row.get(7)?;
            Ok(Folder {
                id: row.get(0)?,
                name: row.get(1)?,
                icon: row.get(2)?,
                color: row.get(3)?,
                order_index: row.get(4)?,
                note_count: row.get(5)?,
                created_at: DateTime::parse_from_rfc3339(&created_str)
                    .unwrap_or_default()
                    .with_timezone(&Utc),
                updated_at: DateTime::parse_from_rfc3339(&updated_str)
                    .unwrap_or_default()
                    .with_timezone(&Utc),
            })
        })?;

        let mut folders = Vec::new();
        for folder in rows {
            folders.push(folder?);
        }
        Ok(folders)
    }

    pub fn create_folder(&self, name: &str, icon: &str, color: &str) -> Result<Folder> {
        let conn = self.conn.lock().unwrap();
        let id = Uuid::new_v4().to_string();
        let now = Utc::now();
        let now_str = now.to_rfc3339();

        let max_order: i32 = conn
            .query_row("SELECT COALESCE(MAX(order_index), 0) + 1 FROM folders", [], |r| r.get(0))
            .unwrap_or(0);

        conn.execute(
            "INSERT INTO folders (id, name, icon, color, order_index, created_at, updated_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![id, name, icon, color, max_order, now_str, now_str],
        )?;

        Ok(Folder {
            id,
            name: name.to_string(),
            icon: icon.to_string(),
            color: color.to_string(),
            order_index: max_order,
            note_count: 0,
            created_at: now,
            updated_at: now,
        })
    }

    pub fn update_folder(&self, id: &str, name: Option<&str>, icon: Option<&str>, color: Option<&str>) -> Result<Folder> {
        let conn = self.conn.lock().unwrap();
        let now = Utc::now();
        let now_str = now.to_rfc3339();

        if let Some(n) = name {
            conn.execute(
                "UPDATE folders SET name = ?1, updated_at = ?2 WHERE id = ?3",
                params![n, now_str, id],
            )?;
        }
        if let Some(i) = icon {
            conn.execute(
                "UPDATE folders SET icon = ?1, updated_at = ?2 WHERE id = ?3",
                params![i, now_str, id],
            )?;
        }
        if let Some(c) = color {
            conn.execute(
                "UPDATE folders SET color = ?1, updated_at = ?2 WHERE id = ?3",
                params![c, now_str, id],
            )?;
        }

        drop(conn);
        self.get_folder_by_id(id)
    }

    pub fn get_folder_by_id(&self, id: &str) -> Result<Folder> {
        let conn = self.conn.lock().unwrap();
        conn.query_row(
            r#"
            SELECT f.id, f.name, f.icon, f.color, f.order_index,
                   (SELECT COUNT(*) FROM notes n WHERE n.folder_id = f.id AND n.is_deleted = 0) as note_count,
                   f.created_at, f.updated_at
            FROM folders f
            WHERE f.id = ?1
            "#,
            params![id],
            |row| {
                let created_str: String = row.get(6)?;
                let updated_str: String = row.get(7)?;
                Ok(Folder {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    icon: row.get(2)?,
                    color: row.get(3)?,
                    order_index: row.get(4)?,
                    note_count: row.get(5)?,
                    created_at: DateTime::parse_from_rfc3339(&created_str)
                        .unwrap_or_default()
                        .with_timezone(&Utc),
                    updated_at: DateTime::parse_from_rfc3339(&updated_str)
                        .unwrap_or_default()
                        .with_timezone(&Utc),
                })
            },
        )
        .context("Folder not found")
    }

    pub fn delete_folder(&self, id: &str) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM folders WHERE id = ?1", params![id])?;
        Ok(())
    }

    pub fn get_notes_summaries(
        &self,
        folder_id: Option<&str>,
        search: Option<&str>,
        pinned_only: bool,
        include_deleted: bool,
    ) -> Result<Vec<NoteSummary>> {
        let conn = self.conn.lock().unwrap();

        let mut query = String::from(
            r#"
            SELECT n.id, n.folder_id, n.title, n.body, n.is_pinned, n.is_deleted,
                   (SELECT COUNT(*) FROM attachments a WHERE a.note_id = n.id) as attachment_count,
                   (SELECT cdn_url FROM attachments a WHERE a.note_id = n.id AND (a.mime_type LIKE 'image/%') LIMIT 1) as preview_image_url,
                   n.created_at, n.updated_at
            FROM notes n
            WHERE 1=1
            "#,
        );

        if !include_deleted {
            query.push_str(" AND n.is_deleted = 0");
        } else {
            query.push_str(" AND n.is_deleted = 1");
        }

        if pinned_only {
            query.push_str(" AND n.is_pinned = 1");
        }

        if let Some(fid) = folder_id {
            if fid != "all" {
                query.push_str(&format!(" AND n.folder_id = '{}'", fid.replace('\'', "''")));
            }
        }

        if let Some(s) = search {
            if !s.trim().is_empty() {
                let term = format!("%{}%", s.trim().replace('\'', "''"));
                query.push_str(&format!(" AND (n.title LIKE '{}' OR n.body LIKE '{}')", term, term));
            }
        }

        query.push_str(" ORDER BY n.is_pinned DESC, n.updated_at DESC");

        let mut stmt = conn.prepare(&query)?;
        let rows = stmt.query_map([], |row| {
            let id: String = row.get(0)?;
            let folder_id: String = row.get(1)?;
            let title: String = row.get(2)?;
            let body: String = row.get(3)?;
            let is_pinned: i32 = row.get(4)?;
            let is_deleted: i32 = row.get(5)?;
            let attachment_count: i64 = row.get(6)?;
            let preview_image_url: Option<String> = row.get(7)?;
            let created_str: String = row.get(8)?;
            let updated_str: String = row.get(9)?;

            // Extract snippet: first non-empty line of body (excluding title if same)
            let snippet = body
                .lines()
                .find(|line| !line.trim().is_empty() && *line != title)
                .unwrap_or("")
                .trim()
                .chars()
                .take(120)
                .collect::<String>();

            Ok(NoteSummary {
                id,
                folder_id,
                title: if title.is_empty() { "New Note".to_string() } else { title },
                snippet,
                is_pinned: is_pinned != 0,
                is_deleted: is_deleted != 0,
                attachment_count,
                preview_image_url,
                created_at: DateTime::parse_from_rfc3339(&created_str)
                    .unwrap_or_default()
                    .with_timezone(&Utc),
                updated_at: DateTime::parse_from_rfc3339(&updated_str)
                    .unwrap_or_default()
                    .with_timezone(&Utc),
            })
        })?;

        let mut list = Vec::new();
        for item in rows {
            list.push(item?);
        }
        Ok(list)
    }

    pub fn get_note_by_id(&self, id: &str) -> Result<Note> {
        let conn = self.conn.lock().unwrap();

        let note_result = conn.query_row(
            "SELECT id, folder_id, title, body, is_pinned, is_deleted, b2_key, b2_url, created_at, updated_at \
             FROM notes WHERE id = ?1",
            params![id],
            |row| {
                let id: String = row.get(0)?;
                let folder_id: String = row.get(1)?;
                let title: String = row.get(2)?;
                let body: String = row.get(3)?;
                let is_pinned: i32 = row.get(4)?;
                let is_deleted: i32 = row.get(5)?;
                let b2_key: Option<String> = row.get(6)?;
                let b2_url: Option<String> = row.get(7)?;
                let created_str: String = row.get(8)?;
                let updated_str: String = row.get(9)?;

                Ok((
                    id,
                    folder_id,
                    title,
                    body,
                    is_pinned != 0,
                    is_deleted != 0,
                    b2_key,
                    b2_url,
                    created_str,
                    updated_str,
                ))
            },
        ).context("Note not found")?;

        let mut stmt = conn.prepare(
            "SELECT id, note_id, file_name, mime_type, byte_size, b2_key, cdn_url, created_at \
             FROM attachments WHERE note_id = ?1 ORDER BY created_at ASC",
        )?;

        let attachments_iter = stmt.query_map(params![id], |row| {
            let created_str: String = row.get(7)?;
            Ok(Attachment {
                id: row.get(0)?,
                note_id: row.get(1)?,
                file_name: row.get(2)?,
                mime_type: row.get(3)?,
                byte_size: row.get(4)?,
                b2_key: row.get(5)?,
                cdn_url: row.get(6)?,
                created_at: DateTime::parse_from_rfc3339(&created_str)
                    .unwrap_or_default()
                    .with_timezone(&Utc),
            })
        })?;

        let mut attachments = Vec::new();
        for att in attachments_iter {
            attachments.push(att?);
        }

        let (note_id, folder_id, title, body, is_pinned, is_deleted, b2_key, b2_url, created_str, updated_str) = note_result;

        Ok(Note {
            id: note_id,
            folder_id,
            title,
            body,
            is_pinned,
            is_deleted,
            b2_key,
            b2_url,
            attachments,
            created_at: DateTime::parse_from_rfc3339(&created_str)
                .unwrap_or_default()
                .with_timezone(&Utc),
            updated_at: DateTime::parse_from_rfc3339(&updated_str)
                .unwrap_or_default()
                .with_timezone(&Utc),
        })
    }

    pub fn create_note(
        &self,
        id: Option<String>,
        folder_id: &str,
        title: &str,
        body: &str,
        is_pinned: bool,
    ) -> Result<Note> {
        let conn = self.conn.lock().unwrap();
        let note_id = id.unwrap_or_else(|| Uuid::new_v4().to_string());
        let now = Utc::now();
        let now_str = now.to_rfc3339();

        conn.execute(
            "INSERT INTO notes (id, folder_id, title, body, is_pinned, is_deleted, created_at, updated_at) \
             VALUES (?1, ?2, ?3, ?4, ?5, 0, ?6, ?7)",
            params![
                note_id,
                folder_id,
                title,
                body,
                if is_pinned { 1 } else { 0 },
                now_str,
                now_str
            ],
        )?;

        drop(conn);
        self.get_note_by_id(&note_id)
    }

    pub fn update_note(
        &self,
        id: &str,
        folder_id: Option<&str>,
        title: Option<&str>,
        body: Option<&str>,
        is_pinned: Option<bool>,
        is_deleted: Option<bool>,
        b2_key: Option<&str>,
        b2_url: Option<&str>,
    ) -> Result<Note> {
        let conn = self.conn.lock().unwrap();
        let now = Utc::now();
        let now_str = now.to_rfc3339();

        if let Some(f) = folder_id {
            conn.execute("UPDATE notes SET folder_id = ?1, updated_at = ?2 WHERE id = ?3", params![f, now_str, id])?;
        }
        if let Some(t) = title {
            conn.execute("UPDATE notes SET title = ?1, updated_at = ?2 WHERE id = ?3", params![t, now_str, id])?;
        }
        if let Some(b) = body {
            conn.execute("UPDATE notes SET body = ?1, updated_at = ?2 WHERE id = ?3", params![b, now_str, id])?;
        }
        if let Some(p) = is_pinned {
            conn.execute("UPDATE notes SET is_pinned = ?1, updated_at = ?2 WHERE id = ?3", params![if p { 1 } else { 0 }, now_str, id])?;
        }
        if let Some(d) = is_deleted {
            conn.execute("UPDATE notes SET is_deleted = ?1, updated_at = ?2 WHERE id = ?3", params![if d { 1 } else { 0 }, now_str, id])?;
        }
        if let Some(k) = b2_key {
            conn.execute("UPDATE notes SET b2_key = ?1, updated_at = ?2 WHERE id = ?3", params![k, now_str, id])?;
        }
        if let Some(u) = b2_url {
            conn.execute("UPDATE notes SET b2_url = ?1, updated_at = ?2 WHERE id = ?3", params![u, now_str, id])?;
        }

        drop(conn);
        self.get_note_by_id(id)
    }

    pub fn delete_note(&self, id: &str, permanent: bool) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        if permanent {
            conn.execute("DELETE FROM notes WHERE id = ?1", params![id])?;
        } else {
            let now_str = Utc::now().to_rfc3339();
            conn.execute(
                "UPDATE notes SET is_deleted = 1, updated_at = ?1 WHERE id = ?2",
                params![now_str, id],
            )?;
        }
        Ok(())
    }

    pub fn toggle_pin(&self, id: &str) -> Result<bool> {
        let conn = self.conn.lock().unwrap();
        let now_str = Utc::now().to_rfc3339();
        conn.execute(
            "UPDATE notes SET is_pinned = 1 - is_pinned, updated_at = ?1 WHERE id = ?2",
            params![now_str, id],
        )?;

        let is_pinned: i32 = conn.query_row(
            "SELECT is_pinned FROM notes WHERE id = ?1",
            params![id],
            |r| r.get(0),
        )?;

        Ok(is_pinned != 0)
    }

    pub fn add_attachment(
        &self,
        note_id: &str,
        file_name: &str,
        mime_type: &str,
        byte_size: i64,
        b2_key: &str,
        cdn_url: &str,
    ) -> Result<Attachment> {
        let conn = self.conn.lock().unwrap();
        let id = Uuid::new_v4().to_string();
        let now = Utc::now();
        let now_str = now.to_rfc3339();

        conn.execute(
            "INSERT INTO attachments (id, note_id, file_name, mime_type, byte_size, b2_key, cdn_url, created_at) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            params![id, note_id, file_name, mime_type, byte_size, b2_key, cdn_url, now_str],
        )?;

        // update note updated_at
        conn.execute(
            "UPDATE notes SET updated_at = ?1 WHERE id = ?2",
            params![now_str, note_id],
        )?;

        Ok(Attachment {
            id,
            note_id: note_id.to_string(),
            file_name: file_name.to_string(),
            mime_type: mime_type.to_string(),
            byte_size,
            b2_key: b2_key.to_string(),
            cdn_url: cdn_url.to_string(),
            created_at: now,
        })
    }
}
