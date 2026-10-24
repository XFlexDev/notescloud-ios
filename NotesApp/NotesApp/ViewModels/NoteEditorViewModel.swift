import Foundation
import SwiftUI
import Combine

public enum SyncState {
    case saved
    case saving
    case error(String)
}

@MainActor
public class NoteEditorViewModel: ObservableObject {
    @Published public var note: Note
    @Published public var titleText: String = ""
    @Published public var bodyText: String = ""
    @Published public var syncState: SyncState = .saved
    @Published public var isUploadingAttachment: Bool = false
    @Published public var showDrawingCanvas: Bool = false
    @Published public var showPhotoPicker: Bool = false
    @Published public var showShareSheet: Bool = false
    @Published public var showDeleteAlert: Bool = false

    private let api = APIService.shared
    private let cache = LocalCacheService.shared
    private var saveCancellable: AnyCancellable?
    private var isInitialLoad = true

    public init(note: Note) {
        self.note = note
        self.titleText = note.title
        self.bodyText = note.body

        // Set up debounced auto-save
        setupAutoSave()
    }

    private func setupAutoSave() {
        saveCancellable = Publishers.CombineLatest($titleText, $bodyText)
            .dropFirst()
            .debounce(for: .milliseconds(800), scheduler: RunLoop.main)
            .sink { [weak self] newTitle, newBody in
                guard let self = self else { return }
                Task {
                    await self.saveCurrentChanges(title: newTitle, body: newBody)
                }
            }
    }

    public func loadFullNote() async {
        if let cached = cache.loadNoteDetail(id: note.id) {
            self.note = cached
            self.titleText = cached.title
            self.bodyText = cached.body
        }

        do {
            let fetched = try await api.fetchNote(id: note.id)
            self.note = fetched
            self.titleText = fetched.title
            self.bodyText = fetched.body
            self.cache.saveNoteDetail(fetched)
        } catch {
            print("Failed to fetch full note: \(error)")
        }
    }

    public func saveCurrentChanges(title: String, body: String) async {
        syncState = .saving
        do {
            let updated = try await api.updateNote(
                id: note.id,
                folderId: note.folderId,
                title: title,
                body: body,
                isPinned: note.isPinned
            )
            self.note = updated
            self.cache.saveNoteDetail(updated)
            self.syncState = .saved
        } catch {
            self.syncState = .error(error.localizedDescription)
        }
    }

    public func togglePin() async {
        NotesTheme.haptic(.medium)
        do {
            let pinned = try await api.togglePin(id: note.id)
            self.note.isPinned = pinned
            self.cache.saveNoteDetail(self.note)
        } catch {
            print("Error toggling pin: \(error)")
        }
    }

    // MARK: - Attachments

    public func uploadAttachmentData(data: Data, fileName: String, mimeType: String) async {
        isUploadingAttachment = true
        NotesTheme.haptic(.light)
        do {
            let attachment = try await api.uploadAttachment(
                noteId: note.id,
                fileData: data,
                fileName: fileName,
                mimeType: mimeType
            )
            self.note.attachments.append(attachment)
            self.cache.saveNoteDetail(self.note)
            NotesTheme.notificationFeedback(.success)
        } catch {
            self.syncState = .error("Upload failed: \(error.localizedDescription)")
            NotesTheme.notificationFeedback(.error)
        }
        isUploadingAttachment = false
    }

    public func insertChecklist() {
        NotesTheme.haptic(.light)
        if bodyText.isEmpty {
            bodyText = "- [ ] "
        } else {
            bodyText += "\n- [ ] "
        }
    }

    public func insertBullet() {
        NotesTheme.haptic(.light)
        if bodyText.isEmpty {
            bodyText = "- "
        } else {
            bodyText += "\n- "
        }
    }
}
