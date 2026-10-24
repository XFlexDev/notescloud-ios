import Foundation

public struct Note: Identifiable, Codable, Hashable {
    public let id: String
    public var folderId: String
    public var title: String
    public var body: String
    public var isPinned: Bool
    public var isDeleted: Bool
    public var b2Key: String?
    public var b2Url: String?
    public var attachments: [Attachment]
    public let createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case folderId = "folder_id"
        case title
        case body
        case isPinned = "is_pinned"
        case isDeleted = "is_deleted"
        case b2Key = "b2_key"
        case b2Url = "b2_url"
        case attachments
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: String = UUID().uuidString,
        folderId: String = "folder-notes-default",
        title: String = "",
        body: String = "",
        isPinned: Bool = false,
        isDeleted: Bool = false,
        b2Key: String? = nil,
        b2Url: String? = nil,
        attachments: [Attachment] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.folderId = folderId
        self.title = title
        self.body = body
        self.isPinned = isPinned
        self.isDeleted = isDeleted
        self.b2Key = b2Key
        self.b2Url = b2Url
        self.attachments = attachments
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        let firstLine = body.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        return firstLine ?? "New Note"
    }

    public var snippet: String {
        let lines = body.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if lines.count > 1 {
            return lines[1]
        } else if let first = lines.first, first != title {
            return first
        }
        return "No additional text"
    }

    public var formattedDate: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        if calendar.isDateInToday(updatedAt) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: updatedAt)
        } else if calendar.isDateInYesterday(updatedAt) {
            return "Yesterday"
        } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()), updatedAt > weekAgo {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: updatedAt)
        } else {
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: updatedAt)
        }
    }

    public var fullDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        return formatter.string(from: updatedAt)
    }

    public var firstImageAttachment: Attachment? {
        attachments.first { $0.isImage }
    }
}

public struct NoteSummary: Identifiable, Codable, Hashable {
    public let id: String
    public let folderId: String
    public let title: String
    public let snippet: String
    public let isPinned: Bool
    public let isDeleted: Bool
    public let attachmentCount: Int
    public let previewImageUrl: String?
    public let createdAt: Date
    public let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case folderId = "folder_id"
        case title
        case snippet
        case isPinned = "is_pinned"
        case isDeleted = "is_deleted"
        case attachmentCount = "attachment_count"
        case previewImageUrl = "preview_image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public var formattedDate: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        if calendar.isDateInToday(updatedAt) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: updatedAt)
        } else if calendar.isDateInYesterday(updatedAt) {
            return "Yesterday"
        } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()), updatedAt > weekAgo {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: updatedAt)
        } else {
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: updatedAt)
        }
    }
}
