import Foundation

public struct Attachment: Identifiable, Codable, Hashable {
    public let id: String
    public let noteId: String
    public let fileName: String
    public let mimeType: String
    public let byteSize: Int64
    public let b2Key: String
    public let cdnUrl: String
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case noteId = "note_id"
        case fileName = "file_name"
        case mimeType = "mime_type"
        case byteSize = "byte_size"
        case b2Key = "b2_key"
        case cdnUrl = "cdn_url"
        case createdAt = "created_at"
    }

    public var isImage: Bool {
        mimeType.hasPrefix("image/")
    }

    public var isAudio: Bool {
        mimeType.hasPrefix("audio/")
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file)
    }
}
