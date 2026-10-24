import SwiftUI

@main
struct NotesApp: App {
    var body: some Scene {
        WindowGroup {
            FolderListView()
                .tint(.notesYellow)
                .preferredColorScheme(nil) // Respect system Dark/Light mode
        }
    }
}
