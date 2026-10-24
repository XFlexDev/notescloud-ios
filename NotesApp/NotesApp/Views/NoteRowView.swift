import SwiftUI

public struct NoteRowView: View {
    public let note: NoteSummary
    public var showFolderBadge: Bool = false

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                // Title
                Text(note.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // Subtitle: Date + Snippet
                HStack(spacing: 6) {
                    Text(note.formattedDate)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.notesSecondary)

                    Text(note.snippet)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.notesSecondary.opacity(0.85))
                        .lineLimit(1)
                }

                // Folder badge if in All Notes
                if showFolderBadge {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                        Text("Notes")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.notesSecondary)
                    .padding(.top, 2)
                }
            }

            Spacer()

            // Thumbnail or Pin Badge
            HStack(spacing: 8) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.notesYellow)
                }

                if let imageUrlString = note.previewImageUrl, let url = URL(string: imageUrlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        default:
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
