import SwiftUI
import PencilKit

public struct DrawingCanvasView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var isSaving = false

    var onSaveDrawing: (Data) -> Void

    public var body: some View {
        NavigationStack {
            ZStack {
                CanvasRepresentable(canvasView: $canvasView, toolPicker: $toolPicker)
                    .background(NotesTheme.paperBackground)
                    .ignoresSafeArea(.all, edges: .bottom)

                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Uploading to B2...")
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.notesCard))
                }
            }
            .navigationTitle("Handwritten Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.notesYellow)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveDrawing()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.notesYellow)
                    .disabled(isSaving)
                }
            }
        }
    }

    private func saveDrawing() {
        isSaving = true
        let image = canvasView.drawing.image(from: canvasView.bounds, scale: 2.0)
        if let pngData = image.pngData() {
            onSaveDrawing(pngData)
        }
        dismiss()
    }
}

struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.backgroundColor = .clear

        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
