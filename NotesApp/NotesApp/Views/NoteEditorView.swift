import SwiftUI
import PhotosUI

public struct NoteEditorView: View {
    @StateObject private var viewModel: NoteEditorViewModel
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isBodyFocused: Bool
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedAttachmentForViewing: Attachment?
    @Environment(\.dismiss) private var dismiss

    public init(note: Note) {
        _viewModel = StateObject(wrappedValue: NoteEditorViewModel(note: note))
    }

    private var isKeyboardActive: Bool {
        isTitleFocused || isBodyFocused
    }

    public var body: some View {
        ZStack {
            NotesTheme.paperBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Date Header (Apple Notes style centered small timestamp)
                    HStack {
                        Spacer()
                        Text(viewModel.note.fullDateString)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.notesSecondary)
                        Spacer()
                    }
                    .padding(.top, 4)

                    // Title
                    TextField("Title", text: $viewModel.titleText, axis: .vertical)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primary)
                        .focused($isTitleFocused)
                        .submitLabel(.next)

                    // Attachments Horizontal/Vertical Carousel
                    if !viewModel.note.attachments.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.note.attachments) { att in
                                    AttachmentThumbnailCard(attachment: att) {
                                        selectedAttachmentForViewing = att
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // Body Editor
                    TextEditor(text: $viewModel.bodyText)
                        .font(.system(size: 16))
                        .lineSpacing(4)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .focused($isBodyFocused)
                        .frame(minHeight: 380)

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                syncStatusView
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Share button
                ShareLink(item: "\(viewModel.titleText)\n\n\(viewModel.bodyText)") {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.notesYellow)
                }

                // Ellipsis menu
                Menu {
                    Button(action: {
                        Task { await viewModel.togglePin() }
                    }) {
                        Label(
                            viewModel.note.isPinned ? "Unpin Note" : "Pin Note",
                            systemImage: viewModel.note.isPinned ? "pin.slash" : "pin"
                        )
                    }

                    if let b2Url = viewModel.note.b2Url, let url = URL(string: b2Url) {
                        ShareLink(item: url) {
                            Label("Share B2 JSON Link", systemImage: "link")
                        }
                    }

                    Divider()

                    Button(role: .destructive, action: {
                        viewModel.showDeleteAlert = true
                    }) {
                        Label("Delete Note", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.notesYellow)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isKeyboardActive {
                FormattingToolbar(viewModel: viewModel) {
                    isTitleFocused = false
                    isBodyFocused = false
                }
            }
        }
        .sheet(isPresented: $viewModel.showDrawingCanvas) {
            DrawingCanvasView { pngData in
                Task {
                    let filename = "sketch_\(Date().timeIntervalSince1970).png"
                    await viewModel.uploadAttachmentData(data: pngData, fileName: filename, mimeType: "image/png")
                }
            }
        }
        .photosPicker(isPresented: $viewModel.showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    let filename = "photo_\(Date().timeIntervalSince1970).jpg"
                    await viewModel.uploadAttachmentData(data: data, fileName: filename, mimeType: "image/jpeg")
                }
                selectedPhotoItem = nil
            }
        }
        .sheet(item: $selectedAttachmentForViewing) { att in
            AttachmentViewer(attachment: att)
        }
        .alert("Delete Note", isPresented: $viewModel.showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await APIService.shared.deleteNote(id: viewModel.note.id)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this note?")
        }
        .task {
            await viewModel.loadFullNote()
        }
    }

    private var syncStatusView: some View {
        HStack(spacing: 5) {
            switch viewModel.syncState {
            case .saved:
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("Saved to B2")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.notesSecondary)
            case .saving:
                ProgressView()
                    .scaleEffect(0.6)
                Text("Syncing...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.notesYellow)
            case .error:
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                Text("Offline Cache")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.notesSecondary)
            }
        }
    }
}

struct AttachmentThumbnailCard: View {
    let attachment: Attachment
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                if attachment.isImage, let url = URL(string: attachment.cdnUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 85)
                                .clipped()
                        default:
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 110, height: 85)
                                .overlay(ProgressView())
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.notesCard)
                        .frame(width: 110, height: 85)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.notesYellow)
                                Text(attachment.fileName)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                            }
                            .padding(6)
                        )
                }

                // Tiny B2 CDN Pill Badge
                HStack(spacing: 3) {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 7))
                    Text("B2")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.6))
                .cornerRadius(4)
                .padding(6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.notesSecondary.opacity(0.2), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}
