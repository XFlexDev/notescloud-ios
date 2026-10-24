import SwiftUI

public struct NotesListView: View {
    @StateObject private var viewModel: NotesListViewModel
    @State private var selectedNoteForEditing: Note?
    @State private var navigateToNewNote: Bool = false
    @State private var newCreatedNote: Note?

    public init(folder: Folder) {
        _viewModel = StateObject(wrappedValue: NotesListViewModel(folder: folder))
    }

    public var body: some View {
        ZStack {
            List {
                // Pinned Section
                if !viewModel.pinnedNotes.isEmpty {
                    Section {
                        ForEach(viewModel.pinnedNotes) { note in
                            NavigationLink(value: note) {
                                NoteRowView(note: note, showFolderBadge: viewModel.folder.id == "all")
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task { await viewModel.togglePin(note: note) }
                                } label: {
                                    Label("Unpin", systemImage: "pin.slash.fill")
                                }
                                .tint(.notesYellow)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteNote(id: note.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                            }
                            .contextMenu {
                                noteContextMenu(for: note)
                            }
                        }
                    } header: {
                        HStack(spacing: 4) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.notesYellow)
                            Text("PINNED")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                }

                // Today Section
                if !viewModel.todayNotes.isEmpty {
                    noteSection(title: "TODAY", notes: viewModel.todayNotes)
                }

                // Previous 7 Days Section
                if !viewModel.previous7DaysNotes.isEmpty {
                    noteSection(title: "PREVIOUS 7 DAYS", notes: viewModel.previous7DaysNotes)
                }

                // Previous 30 Days Section
                if !viewModel.previous30DaysNotes.isEmpty {
                    noteSection(title: "PREVIOUS 30 DAYS", notes: viewModel.previous30DaysNotes)
                }

                // Older Section
                if !viewModel.olderNotes.isEmpty {
                    noteSection(title: "OLDER", notes: viewModel.olderNotes)
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $viewModel.searchText, prompt: "Search")
            .refreshable {
                await viewModel.loadNotes()
            }
            .overlay {
                if viewModel.notes.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "note.text")
                            .font(.system(size: 48))
                            .foregroundColor(.notesSecondary)
                        Text("No Notes")
                            .font(.headline)
                            .foregroundColor(.notesSecondary)
                        Text("Tap the compose button below to create your first note.")
                            .font(.subheadline)
                            .foregroundColor(.notesSecondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
            }
        }
        .navigationTitle(viewModel.folder.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Menu("Sort By") {
                        ForEach(NoteSortOption.allCases) { option in
                            Button(action: {
                                viewModel.sortOption = option
                            }) {
                                HStack {
                                    Text(option.rawValue)
                                    if viewModel.sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Button(action: {
                        viewModel.isAscending.toggle()
                    }) {
                        Label(
                            viewModel.isAscending ? "Oldest First" : "Newest First",
                            systemImage: viewModel.isAscending ? "arrow.up" : "arrow.down"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.notesYellow)
                }
            }

            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()

                // Center note count
                Text("\(viewModel.filteredNotes.count) Notes")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.notesSecondary)

                Spacer()

                // Compose Button
                Button(action: createNewNote) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20))
                        .foregroundColor(.notesYellow)
                }
            }
        }
        .navigationDestination(for: NoteSummary.self) { summary in
            NoteEditorView(note: Note(
                id: summary.id,
                folderId: summary.folderId,
                title: summary.title,
                body: summary.snippet,
                isPinned: summary.isPinned,
                isDeleted: summary.isDeleted,
                createdAt: summary.createdAt,
                updatedAt: summary.updatedAt
            ))
        }
        .navigationDestination(isPresented: $navigateToNewNote) {
            if let note = newCreatedNote {
                NoteEditorView(note: note)
            }
        }
        .task {
            await viewModel.loadNotes()
        }
    }

    @ViewBuilder
    private func noteSection(title: String, notes: [NoteSummary]) -> some View {
        Section(header: Text(title).font(.system(size: 12, weight: .bold))) {
            ForEach(notes) { note in
                NavigationLink(value: note) {
                    NoteRowView(note: note, showFolderBadge: viewModel.folder.id == "all")
                }
                .swipeActions(edge: .leading) {
                    Button {
                        Task { await viewModel.togglePin(note: note) }
                    } label: {
                        Label("Pin", systemImage: "pin.fill")
                    }
                    .tint(.notesYellow)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteNote(id: note.id) }
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                }
                .contextMenu {
                    noteContextMenu(for: note)
                }
            }
        }
    }

    @ViewBuilder
    private func noteContextMenu(for note: NoteSummary) -> some View {
        Button {
            Task { await viewModel.togglePin(note: note) }
        } label: {
            Label(note.isPinned ? "Unpin Note" : "Pin Note", systemImage: note.isPinned ? "pin.slash" : "pin")
        }

        ShareLink(item: "\(note.title)\n\n\(note.snippet)") {
            Label("Share Note", systemImage: "square.and.arrow.up")
        }

        Divider()

        Button(role: .destructive) {
            Task { await viewModel.deleteNote(id: note.id) }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func createNewNote() {
        NotesTheme.haptic(.medium)
        let targetFolderId = viewModel.folder.id == "all" ? "folder-notes-default" : viewModel.folder.id
        Task {
            do {
                let note = try await APIService.shared.createNote(
                    folderId: targetFolderId,
                    title: "",
                    body: ""
                )
                self.newCreatedNote = note
                self.navigateToNewNote = true
                await viewModel.loadNotes()
            } catch {
                print("Failed to create note: \(error)")
            }
        }
    }
}
