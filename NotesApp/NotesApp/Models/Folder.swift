import Foundation
import SwiftUI

public struct Folder: Identifiable, Codable, Hashable {
    public let id: String
    public var name: String
    public var icon: String
    public var color: String
    public var orderIndex: Int
    public var noteCount: Int
    public let createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case color
        case orderIndex = "order_index"
        case noteCount = "note_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public var systemColor: Color {
        Color(hex: color) ?? NotesTheme.accent
    }

    public static let allNotes = Folder(
        id: "all",
        name: "All NotesCloud",
        icon: "tray.full.fill",
        color: "#E8A738",
        orderIndex: -1,
        noteCount: 0,
        createdAt: Date(),
        updatedAt: Date()
    )

    public static let quickNotes = Folder(
        id: "quick",
        name: "Quick Notes",
        icon: "bolt.fill",
        color: "#FF9500",
        orderIndex: -2,
        noteCount: 0,
        createdAt: Date(),
        updatedAt: Date()
    )
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
