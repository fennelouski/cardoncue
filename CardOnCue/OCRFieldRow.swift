import SwiftUI

/// Row view for displaying and editing an OCR field segment
struct OCRFieldRow: View {
    @Binding var field: OCRField
    @State private var showingCopyConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: field.type.icon)
                .foregroundColor(.appBlue)
                .frame(width: 24)
                .font(.system(size: 16))

            // Label and text field
            VStack(alignment: .leading, spacing: 4) {
                Text(field.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField(field.type.displayName, text: $field.value, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...3)
            }

            // Copy button
            Button(action: {
                copyToClipboard()
            }) {
                Image(systemName: showingCopyConfirmation ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundColor(showingCopyConfirmation ? .green : .appBlue)
                    .font(.system(size: 20))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = field.value

        // Show confirmation
        withAnimation {
            showingCopyConfirmation = true
        }

        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingCopyConfirmation = false
            }
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
