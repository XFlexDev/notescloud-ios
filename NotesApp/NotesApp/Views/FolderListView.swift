import SwiftUI

public struct FolderListView: View {
    @StateObject private var viewModel = FolderListViewModel()
    @State private var showSettings = false
    @State private var navigateToNewNote = false
    @State private var newNote: Note?

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Section: NotesCloud / iCloud
                Section(header: Text("NOTESCLOUD (B2)").font(.system(size: 13, weight: .bold))) {
                    // All Notes
                    NavigationLink(destination: NotesListView(folder: Folder(
                        id: "all",
                        name: "All Notes",
                        icon: "tray.full.fill",
                        color: "#E8A738",
                        orderIndex: -1,
                        noteCount: viewModel.totalNotesCount,
                        createdAt: Date(),
                        updatedAt: Date()
                    ))) {
                        folderRow(title: "All Notes", icon: "tray.full.fill", color: .notesYellow, count: viewModel.totalNotesCount)
                    }

                    // Quick Notes
                    NavigationLink(destination: NotesListView(folder: Folder.quickNotes)) {
                        folderRow(title: "Quick Notes", icon: "bolt.fill", color: .orange, count: 0)
                    }

                    // Default Notes Folder
                    NavigationLink(destination: NotesListView(folder: Folder(
                        id: "folder-notes-default",
                        name: "Notes",
                        icon: "folder",
                        color: "#E8A738",
                        orderIndex: 0,
                        noteCount: viewModel.customFolders.first(where: { $0.id == "folder-notes-default" })?.noteCount ?? 0,
                        createdAt: Date(),
                        updatedAt: Date()
                    ))) {
                        folderRow(
                            title: "Notes",
                            icon: "folder",
                            color: .notesYellow,
                            count: viewModel.customFolders.first(where: { $0.id == "folder-notes-default" })?.noteCount ?? 0
                        )
                    }
                }

                // Section: Custom Folders
                let otherFolders = viewModel.customFolders.filter { $0.id != "folder-notes-default" }
                if !otherFolders.isEmpty {
                    Section(header: Text("FOLDERS").font(.system(size: 13, weight: .bold))) {
                        ForEach(otherFolders) { folder in
                            NavigationLink(destination: NotesListView(folder: folder)) {
                                folderRow(
                                    title: folder.name,
                                    icon: folder.icon,
                                    color: folder.systemColor,
                                    count: folder.noteCount
                                )
                            }
                        }
                        .onDelete(perform: viewModel.deleteFolder)
                    }
                }

                // Section: Trash
                Section {
                    NavigationLink(destination: NotesListView(folder: Folder(
                        id: "deleted",
                        name: "Recently Deleted",
                        icon: "trash",
                        color: "#8E8E93",
                        orderIndex: 999,
                        noteCount: 0,
                        createdAt: Date(),
                        updatedAt: Date()
                    ))) {
                        folderRow(title: "Recently Deleted", icon: "trash", color: .notesSecondary, count: 0)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Folders")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                        .foregroundColor(.notesYellow)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.notesYellow)
                    }
                }

                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: {
                        viewModel.showNewFolderAlert = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.plus")
                            Text("New Folder")
                        }
                        .foregroundColor(.notesYellow)
                    }

                    Spacer()

                    Button(action: createQuickNote) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20))
                            .foregroundColor(.notesYellow)
                    }
                }
            }
            .alert("New Folder", isPresented: $viewModel.showNewFolderAlert) {
                TextField("Folder Name", text: $viewModel.newFolderName)
                Button("Save") {
                    Task {
                        await viewModel.createFolder(name: viewModel.newFolderName)
                        viewModel.newFolderName = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.newFolderName = ""
                }
            } message: {
                Text("Enter a name for this folder.")
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(isPresented: $navigateToNewNote) {
                if let note = newNote {
                    NoteEditorView(note: note)
                }
            }
            .refreshable {
                await viewModel.loadFolders()
            }
            .task {
                await viewModel.loadFolders()
            }
        }
    }

    private func folderRow(title: String, icon: String, color: Color, count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 24, alignment: .center)

            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.primary)

            Spacer()

            Text("\(count)")
                .font(.system(size: 15))
                .foregroundColor(.notesSecondary)
        }
        .padding(.vertical, 2)
    }

    private func createQuickNote() {
        NotesTheme.haptic(.medium)
        Task {
            do {
                let created = try await APIService.shared.createNote(
                    folderId: "folder-notes-default",
                    title: "",
                    body: ""
                )
                self.newNote = created
                self.navigateToNewNote = true
                await viewModel.loadFolders()
            } catch {
                print("Failed to create note: \(error)")
            }
        }
    }
}
