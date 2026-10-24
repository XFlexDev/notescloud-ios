# NotesCloud — Native iOS Notes with Backblaze B2 & Rust Backend

> A native iOS SwiftUI Notes app that meticulously replicates the authentic Apple Notes experience, backed by a high-performance Rust server with Backblaze B2 cloud storage and Cloudflare Edge CDN delivery.

---

## 🌟 Highlights

- **Authentic Apple Notes Design**:
  - Signature Apple Notes Gold/Amber accent (`#E8A738`).
  - Native iOS Inset Grouped layout, paper background tones for Light and Dark modes.
  - Three-tier navigation: **Folders** &rarr; **Notes List** &rarr; **Note Editor**.
  - Smart date-grouped sections: **PINNED**, **TODAY**, **PREVIOUS 7 DAYS**, **PREVIOUS 30 DAYS**, **OLDER**.
  - Note list cards showing Title, timestamp, snippet preview, and image thumbnails.
  - Swipe actions (Leading: Pin/Unpin; Trailing: Move, Delete) & Context menus.
- **Backblaze B2 Storage Integration**:
  - Every note snapshot is automatically serialized and backed up to Backblaze B2 (`kreatix-agy` bucket).
  - All media attachments (photos, drawings, voice memos, files) upload directly to B2.
  - CDN links formatted exclusively via `https://cdn.kreatix.dev/file/kreatix-agy/...` eliminating egress fees.
- **PencilKit Canvas**:
  - Native Apple PencilKit drawing canvas (`PKCanvasView`, `PKToolPicker`).
  - Sketch drawings with pens, pencils, markers, and color palettes; renders to PNG and streams to B2.
- **Offline First**:
  - Immediate launch with zero spinner delay via local JSON disk cache.
  - Background synchronization and conflict resolution.
- **High-Performance Rust Backend**:
  - Built with Axum 0.7, Tokio, SQLite WAL mode, and pure Rustls.
  - Live production endpoint active at `https://notes.kreatix.dev`.
  - Managed via Systemd (`notes-server.service`).

---

## 📂 Project Structure

```
/root/ios-notes/
├── NotesApp/                             # Native iOS SwiftUI Project
│   ├── NotesApp.xcodeproj/               # Xcode Project file (Ready to open in Xcode)
│   │   └── project.pbxproj
│   ├── Package.swift                     # Swift Package Manager manifest
│   └── NotesApp/
│       ├── NotesApp.swift                # App entry point with custom yellow tint
│       ├── Info.plist                    # Camera, Photo Library, & Network permissions
│       ├── Theme/
│       │   └── NotesTheme.swift          # Colors, paper tones, haptics & typography
│       ├── Models/
│       │   ├── Note.swift                # Note & NoteSummary data models
│       │   ├── Folder.swift              # Folder model with color & SF Symbols
│       │   └── Attachment.swift          # Attachment model with B2 & CDN metadata
│       ├── Services/
│       │   ├── APIService.swift          # HTTP client for Rust backend
│       │   └── LocalCacheService.swift   # Offline local disk caching
│       ├── ViewModels/
│       │   ├── FolderListViewModel.swift # Folders state & CRUD
│       │   ├── NotesListViewModel.swift  # Sorting, filtering, date grouping
│       │   └── NoteEditorViewModel.swift # Debounced autosave & B2 uploads
│       └── Views/
│           ├── FolderListView.swift      # Root Folders screen
│           ├── NotesListView.swift       # Grouped notes list with search
│           ├── NoteEditorView.swift      # Paper editor canvas with attachments
│           ├── NoteRowView.swift         # Individual note card row
│           ├── DrawingCanvasView.swift   # PencilKit drawing & sketching
│           ├── AttachmentViewer.swift    # Fullscreen attachment zoom & share
│           ├── FormattingToolbar.swift   # Keyboard accessory toolbar
│           └── SettingsView.swift        # Server URL, B2 status, cache manager
│
└── server/                               # Rust Backend Server
    ├── Cargo.toml
    └── src/
        ├── main.rs                       # Axum routing, dashboard, CORS & tracing
        ├── config.rs                     # Environment & credentials loader
        ├── models.rs                     # Serde models for notes, folders, attachments
        ├── db.rs                         # SQLite storage & indexing
        ├── b2.rs                         # Backblaze B2 client & CDN URL generator
        └── routes/
            ├── mod.rs
            ├── folders.rs                # Folder endpoints
            ├── notes.rs                  # Note CRUD, pin toggling, B2 snapshot sync
            ├── attachments.rs            # Multipart uploads directly to B2
            └── sync.rs                   # Batch reconciliation
```

---

## 🚀 Running the iOS App in Xcode

1. Copy or clone the `NotesApp` folder to your Mac:
   ```bash
   scp -r root@<server>:/root/ios-notes/NotesApp ~/Desktop/NotesApp
   ```
2. Double-click `NotesApp.xcodeproj` to open it in Xcode 15 or 16.
3. Select an iOS Simulator (e.g., iPhone 16 Pro) or your connected physical iPhone.
4. Press **⌘R** (Run) to build and launch!
5. In the app, tap the **Settings** gear icon in the top right:
   - Default Server URL is preconfigured to: `https://notes.kreatix.dev`
   - Tap **"Test Server & B2 Connection"** to verify edge connectivity.

---

## 🌐 Server API & Live Status

The server is currently running in production under systemd:

```bash
# Check service status
systemctl status notes-server

# Live logs
journalctl -u notes-server -f
```

### Public Endpoint:
`https://notes.kreatix.dev`

### REST API Reference:

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/health` | Server status & B2 storage check |
| `GET` | `/api/folders` | List all folders with live note counts |
| `POST` | `/api/folders` | Create a new custom folder |
| `GET` | `/api/notes?folder_id=...` | List note summaries (supports search & pinned filter) |
| `GET` | `/api/notes/:id` | Fetch complete note with body & attachments |
| `POST` | `/api/notes` | Create a note (syncs snapshot to B2) |
| `PUT` | `/api/notes/:id` | Update note title/body/folder (syncs to B2) |
| `POST` | `/api/notes/:id/pin` | Toggle pinned status |
| `DELETE`| `/api/notes/:id` | Move note to trash or permanent delete |
| `POST` | `/api/notes/:id/attachments` | Upload image/sketch directly to Backblaze B2 |
| `POST` | `/api/sync` | Batch sync for offline reconciliation |

### Example cURL Commands:

```bash
# Health check
curl -s https://notes.kreatix.dev/api/health | jq .

# Create a note
curl -s -X POST https://notes.kreatix.dev/api/notes \
  -H "Content-Type: application/json" \
  -d '{"folder_id":"folder-notes-default","title":"Meeting Notes","body":"Meeting Notes\n\n- Q4 Goals\n- Architecture review"}' | jq .

# Upload photo/drawing to B2
curl -s -X POST https://notes.kreatix.dev/api/notes/<NOTE_ID>/attachments \
  -F "file=@photo.jpg;type=image/jpeg" | jq .
```
