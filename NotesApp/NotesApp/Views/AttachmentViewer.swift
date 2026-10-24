import SwiftUI

public struct AttachmentViewer: View {
    public let attachment: Attachment
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if attachment.isImage, let url = URL(string: attachment.cdnUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure(let error):
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 36))
                                    .foregroundColor(.orange)
                                Text("Failed to load image: \(error.localizedDescription)")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.notesYellow)
                        Text(attachment.fileName)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(attachment.formattedSize)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("Stored on Backblaze B2")
                            .font(.caption)
                            .foregroundColor(.notesYellow)
                    }
                }
            }
            .navigationTitle(attachment.fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.notesYellow)
                }

                if let url = URL(string: attachment.cdnUrl) {
                    ToolbarItem(placement: .bottomBar) {
                        ShareLink(item: url) {
                            Label("Share B2 Link", systemImage: "square.and.arrow.up")
                                .foregroundColor(.notesYellow)
                        }
                    }
                }
            }
        }
    }
}
