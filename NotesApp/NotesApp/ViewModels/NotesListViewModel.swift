import Foundation
import SwiftUI

public enum NoteSortOption: String, CaseIterable, Identifiable {
    case dateEdited = "Date Edited"
    case dateCreated = "Date Created"
    case title = "Title"

    public var id: String { rawValue }
}

@MainActor
public class NotesListViewModel: ObservableObject {
    public let folder: Folder
    @Published public var notes: [NoteSummary] = []
    @Published public var searchText: String = ""
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var sortOption: NoteSortOption = .dateEdited
    @Published public var isAscending: Bool = false

    private let api = APIService.shared
    private let cache = LocalCacheService.shared

    public init(folder: Folder) {
        self.folder = folder
        if let cached = cache.loadNotes(folderId: folder.id) {
            self.notes = cached
        }
    }

    public var filteredNotes: [NoteSummary] {
        var result = notes
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) || $0.snippet.lowercased().contains(query)
            }
        }

        switch sortOption {
        case .dateEdited:
            result.sort { isAscending ? $0.updatedAt < $1.updatedAt : $0.updatedAt > $1.updatedAt }
        case .dateCreated:
            result.sort { isAscending ? $0.createdAt < $1.createdAt : $0.createdAt > $1.createdAt }
        case .title:
            result.sort { isAscending ? $0.title < $1.title : $0.title > $1.title }
        }

        return result
    }

    public var pinnedNotes: [NoteSummary] {
        filteredNotes.filter { $0.isPinned }
    }

    public var unpinnedNotes: [NoteSummary] {
        filteredNotes.filter { !$0.isPinned }
    }

    public var todayNotes: [NoteSummary] {
        let calendar = Calendar.current
        return unpinnedNotes.filter { calendar.isDateInToday($0.updatedAt) }
    }

    public var previous7DaysNotes: [NoteSummary] {
        let calendar = Calendar.current
        let today = Date()
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) else { return [] }
        return unpinnedNotes.filter {
            !calendar.isDateInToday($0.updatedAt) && $0.updatedAt >= sevenDaysAgo
        }
    }

    public var previous30DaysNotes: [NoteSummary] {
        let calendar = Calendar.current
        let today = Date()
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today),
              let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) else { return [] }
        return unpinnedNotes.filter {
            $0.updatedAt < sevenDaysAgo && $0.updatedAt >= thirtyDaysAgo
        }
    }

    public var olderNotes: [NoteSummary] {
        let calendar = Calendar.current
        let today = Date()
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) else { return [] }
        return unpinnedNotes.filter { $0.updatedAt < thirtyDaysAgo }
    }

    public func loadNotes() async {
        isLoading = true
        errorMessage = nil
        do {
            let list = try await api.fetchNotes(folderId: folder.id, search: nil)
            self.notes = list
            self.cache.saveNotes(list, folderId: folder.id)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    public func togglePin(note: NoteSummary) async {
        NotesTheme.haptic(.medium)
        do {
            let newStatus = try await api.togglePin(id: note.id)
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                let updated = NoteSummary(
                    id: note.id,
                    folderId: note.folderId,
                    title: note.title,
                    snippet: note.snippet,
                    isPinned: newStatus,
                    isDeleted: note.isDeleted,
                    attachmentCount: note.attachmentCount,
                    previewImageUrl: note.previewImageUrl,
                    createdAt: note.createdAt,
                    updatedAt: Date()
                )
                notes[index] = updated
                cache.saveNotes(notes, folderId: folder.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deleteNote(id: String) async {
        NotesTheme.haptic(.medium)
        notes.removeAll { $0.id == id }
        cache.saveNotes(notes, folderId: folder.id)
        try? await api.deleteNote(id: id)
    }
}
