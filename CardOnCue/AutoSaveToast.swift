import SwiftUI

/// Floating toast notification displayed after auto-saving a card
struct AutoSaveToast: View {

    // MARK: - Properties

    let cardName: String
    let confidence: Float
    let onEdit: () -> Void
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible = true

    // MARK: - Body

    var body: some View {
        VStack {
            if isVisible {
                HStack(spacing: 12) {
                    // Success icon
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)

                    // Card info
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Saved: \(cardName)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text("\(Int(confidence * 100))% confidence")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Action buttons
                    HStack(spacing: 8) {
                        Button(action: {
                            withAnimation {
                                isVisible = false
                            }
                            onEdit()
                        }) {
                            Text("Edit")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            withAnimation {
                                isVisible = false
                            }
                            onUndo()
                        }) {
                            Text("Undo")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isVisible = false
                }
                // Call dismiss callback after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onDismiss()
                }
            }
        }
    }
}

// MARK: - Toast Modifier

/// ViewModifier to add auto-save toast to any view
struct AutoSaveToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let cardName: String
    let confidence: Float
    let onEdit: () -> Void
    let onUndo: () -> Void

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if isPresented {
                AutoSaveToast(
                    cardName: cardName,
                    confidence: confidence,
                    onEdit: onEdit,
                    onUndo: onUndo,
                    onDismiss: {
                        isPresented = false
                    }
                )
                .padding(.top, 8)
                .zIndex(999)
            }
        }
    }
}

extension View {
    /// Add auto-save toast overlay to a view
    func autoSaveToast(
        isPresented: Binding<Bool>,
        cardName: String,
        confidence: Float,
        onEdit: @escaping () -> Void,
        onUndo: @escaping () -> Void
    ) -> some View {
        modifier(AutoSaveToastModifier(
            isPresented: isPresented,
            cardName: cardName,
            confidence: confidence,
            onEdit: onEdit,
            onUndo: onUndo
        ))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        VStack {
            AutoSaveToast(
                cardName: "Luke's Chuck E. Cheese",
                confidence: 0.92,
                onEdit: { print("Edit tapped") },
                onUndo: { print("Undo tapped") },
                onDismiss: { print("Toast dismissed") }
            )
            .padding(.top, 50)

            Spacer()
        }
    }
}
