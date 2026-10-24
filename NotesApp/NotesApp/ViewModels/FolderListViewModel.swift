import Foundation
import SwiftUI

@MainActor
public class FolderListViewModel: ObservableObject {
    @Published public var customFolders: [Folder] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var searchText = ""
    @Published public var showNewFolderAlert = false
    @Published public var newFolderName = ""
    @Published public var totalNotesCount: Int = 0

    private let api = APIService.shared
    private let cache = LocalCacheService.shared

    public init() {
        if let cached = cache.loadFolders() {
            self.customFolders = cached
            self.totalNotesCount = cached.reduce(0) { $0 + $1.noteCount }
        }
    }

    public func loadFolders() async {
        isLoading = true
        errorMessage = nil
        do {
            let folders = try await api.fetchFolders()
            self.customFolders = folders
            self.totalNotesCount = folders.reduce(0) { $0 + $1.noteCount }
            self.cache.saveFolders(folders)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    public func createFolder(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let folder = try await api.createFolder(name: trimmed)
            self.customFolders.append(folder)
            self.cache.saveFolders(self.customFolders)
            NotesTheme.notificationFeedback(.success)
        } catch {
            self.errorMessage = error.localizedDescription
            NotesTheme.notificationFeedback(.error)
        }
    }

    public func deleteFolder(at offsets: IndexSet) {
        for index in offsets {
            let folder = customFolders[index]
            customFolders.remove(at: index)
            Task {
                try? await api.deleteFolder(id: folder.id)
                self.cache.saveFolders(self.customFolders)
            }
        }
    }
}
