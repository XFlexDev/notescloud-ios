import SwiftUI

public struct FormattingToolbar: View {
    @ObservedObject var viewModel: NoteEditorViewModel
    var onDismissKeyboard: () -> Void

    public var body: some View {
        HStack(spacing: 24) {
            // Checklist button
            Button(action: {
                viewModel.insertChecklist()
            }) {
                Image(systemName: "checklist")
                    .font(.system(size: 20))
                    .foregroundColor(.notesYellow)
            }

            // Photo / Camera button
            Button(action: {
                viewModel.showPhotoPicker = true
            }) {
                Image(systemName: "camera")
                    .font(.system(size: 20))
                    .foregroundColor(.notesYellow)
            }

            // Pencil / Drawing button
            Button(action: {
                viewModel.showDrawingCanvas = true
            }) {
                Image(systemName: "pencil.tip.crop.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.notesYellow)
            }

            // Bullet list
            Button(action: {
                viewModel.insertBullet()
            }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20))
                    .foregroundColor(.notesYellow)
            }

            Spacer()

            // Done button to hide keyboard
            Button(action: onDismissKeyboard) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.notesYellow)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(
            Color(uiColor: .secondarySystemBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: -2)
        )
    }
}
