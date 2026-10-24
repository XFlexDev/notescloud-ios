# NotesCloud — Native iOS Notes with Backblaze B2 & Rust Backend

> A native iOS SwiftUI Notes app that meticulously replicates the authentic Apple Notes experience, targeting **iOS 27.0.1** and **Xcode 27**, backed by a high-performance Rust server with Backblaze B2 cloud storage and Cloudflare Edge CDN delivery.

---

## 🌟 Highlights

- **Unsigned IPA Ready**:
  - Direct Download: [NotesApp-unsigned.ipa](https://cdn.kreatix.dev/file/kreatix-agy/NotesApp-unsigned.ipa)
  - Full Xcode Project Zip: [NotesApp-iOS-SwiftUI.zip](https://cdn.kreatix.dev/file/kreatix-agy/NotesApp-iOS-SwiftUI.zip)
  - GitHub Repository: [https://github.com/XFlexDev/notescloud-ios](https://github.com/XFlexDev/notescloud-ios)
- **Zero Emojis for Icons**:
  - Strictly 100% vector Apple SF Symbols (`Image(systemName: ...)`) and SVG iconography throughout the app and backend dashboard.
- **Target Specifications**:
  - **iOS Deployment Target**: `27.0.1` (`MinimumOSVersion = 27.0.1`)
  - **Xcode Version**: `Xcode 27` (`DTXcode = 2700`, `LastUpgradeCheck = 2700`)
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

## 🛠 GitHub Actions CI/CD Workflow

The repository includes a GitHub Actions workflow (`.github/workflows/build-ios.yml`) that runs on macOS with Xcode 27 to build the project and package the unsigned `.ipa`:

```yaml
name: Build iOS Notes App (Unsigned IPA)

on:
  push:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  build:
    name: Build Unsigned IPA
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Build NotesApp (Unsigned Release)
        run: |
          xcodebuild clean build \
            -project NotesApp/NotesApp.xcodeproj \
            -scheme NotesApp \
            -configuration Release \
            -sdk iphoneos \
            -derivedDataPath build/DerivedData \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGN_IDENTITY="" \
            IPHONEOS_DEPLOYMENT_TARGET=27.0.1
      - name: Package Unsigned IPA
        run: |
          mkdir -p build/Payload
          APP_DIR=$(find build/DerivedData/Build/Products -name "*.app" -type d | head -n 1)
          cp -R "$APP_DIR" build/Payload/
          cd build && zip -r NotesApp-unsigned.ipa Payload/
      - uses: actions/upload-artifact@v4
        with:
          name: NotesApp-unsigned-ipa
          path: build/NotesApp-unsigned.ipa
```

---

## 📲 Installing the Unsigned IPA

You can sideload the unsigned IPA onto your iOS device using any standard tool:
- **TrollStore** (permanent, no revokes)
- **AltStore** or **SideStore**
- **Sideloadly**
- **Xcode Devices & Simulators window** (`xcrun devicectl device install app ...`)

Direct Download URL:
`https://cdn.kreatix.dev/file/kreatix-agy/NotesApp-unsigned.ipa`
