import SwiftUI

public enum NotesTheme {
    /// Iconic Apple Notes Gold/Amber accent
    public static let accent = Color(red: 0.91, green: 0.655, blue: 0.22)
    public static let accentDark = Color(red: 0.82, green: 0.58, blue: 0.18)
    public static let accentLight = Color(red: 0.98, green: 0.85, blue: 0.45)

    /// Background Colors
    public static let paperBackgroundLight = Color(red: 0.98, green: 0.98, blue: 0.97)
    public static let paperBackgroundDark = Color(red: 0.11, green: 0.11, blue: 0.118)

    public static let cardBackgroundLight = Color.white
    public static let cardBackgroundDark = Color(red: 0.173, green: 0.173, blue: 0.18)

    public static let secondaryText = Color(red: 0.557, green: 0.557, blue: 0.576)
    public static let separator = Color(red: 0.78, green: 0.78, blue: 0.8).opacity(0.4)

    /// Dynamic paper background that adapts to Light/Dark mode
    public static var paperBackground: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1.0)
                : UIColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1.0)
        })
    }

    /// Dynamic card/cell background
    public static var cardBackground: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.173, green: 0.173, blue: 0.18, alpha: 1.0)
                : UIColor.white
        })
    }

    /// Haptic Feedback Generator
    public static func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    public static func notificationFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

extension Color {
    public static let notesYellow = NotesTheme.accent
    public static let notesPaper = NotesTheme.paperBackground
    public static let notesCard = NotesTheme.cardBackground
    public static let notesSecondary = NotesTheme.secondaryText
}
