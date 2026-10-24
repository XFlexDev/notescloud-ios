import Foundation

public class LocalCacheService {
    public static let shared = LocalCacheService()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("NotesCloudCache")
    }

    private init() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func saveFolders(_ folders: [Folder]) {
        let fileURL = cacheDirectory.appendingPathComponent("cached_folders.json")
        if let data = try? encoder.encode(folders) {
            try? data.write(to: fileURL)
        }
    }

    public func loadFolders() -> [Folder]? {
        let fileURL = cacheDirectory.appendingPathComponent("cached_folders.json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode([Folder].self, from: data)
    }

    public func saveNotes(_ notes: [NoteSummary], folderId: String) {
        let fileURL = cacheDirectory.appendingPathComponent("cached_notes_\(folderId).json")
        if let data = try? encoder.encode(notes) {
            try? data.write(to: fileURL)
        }
    }

    public func loadNotes(folderId: String) -> [NoteSummary]? {
        let fileURL = cacheDirectory.appendingPathComponent("cached_notes_\(folderId).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode([NoteSummary].self, from: data)
    }

    public func saveNoteDetail(_ note: Note) {
        let fileURL = cacheDirectory.appendingPathComponent("note_\(note.id).json")
        if let data = try? encoder.encode(note) {
            try? data.write(to: fileURL)
        }
    }

    public func loadNoteDetail(id: String) -> Note? {
        let fileURL = cacheDirectory.appendingPathComponent("note_\(id).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(Note.self, from: data)
    }
}
