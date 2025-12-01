import SwiftUI
import UIKit

struct PerspectiveCorrectionView: View {
    @Environment(\.dismiss) var dismiss
    let image: UIImage
    let onApply: ([CGPoint]) -> Void

    @State private var cornerPoints: [CGPoint] = []
    @State private var selectedCorner: Int? = nil
    @State private var imageSize: CGSize = .zero

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                instructionBanner

                GeometryReader { geometry in
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .onAppear {
                                setupDefaultPoints(in: geometry.size)
                            }

                        if cornerPoints.count == 4 {
                            PerspectiveOverlay(
                                points: $cornerPoints,
                                selectedCorner: $selectedCorner,
                                imageSize: geometry.size
                            )
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .background(Color.black)

                bottomToolbar
            }
            .navigationTitle("Straighten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply(cornerPoints)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(cornerPoints.count != 4)
                }
            }
        }
    }

    private var instructionBanner: some View {
        VStack(spacing: 4) {
            Text("Drag the corners to match the card edges")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("This will straighten and crop the image")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.appPrimary.opacity(0.1))
    }

    private var bottomToolbar: some View {
        HStack {
            Button(action: resetPoints) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset")
                }
                .font(.subheadline)
                .foregroundColor(.appPrimary)
            }

            Spacer()

            if selectedCorner != nil {
                Text("Corner Selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.05))
    }

    private func setupDefaultPoints(in size: CGSize) {
        let inset: CGFloat = 40
        cornerPoints = [
            CGPoint(x: inset, y: inset), // Top-left
            CGPoint(x: size.width - inset, y: inset), // Top-right
            CGPoint(x: size.width - inset, y: size.height - inset), // Bottom-right
            CGPoint(x: inset, y: size.height - inset) // Bottom-left
        ]
        imageSize = size
    }

    private func resetPoints() {
        setupDefaultPoints(in: imageSize)
    }
}

struct PerspectiveOverlay: View {
    @Binding var points: [CGPoint]
    @Binding var selectedCorner: Int?
    let imageSize: CGSize

    var body: some View {
        ZStack {
            Path { path in
                guard points.count == 4 else { return }

                path.move(to: points[0])
                for i in 1..<4 {
                    path.addLine(to: points[i])
                }
                path.closeSubpath()
            }
            .stroke(Color.appPrimary, lineWidth: 2)

            ForEach(0..<4, id: \.self) { index in
                if points.count > index {
                    DraggableCorner(
                        position: $points[index],
                        isSelected: selectedCorner == index,
                        imageSize: imageSize,
                        onSelect: {
                            selectedCorner = index
                        },
                        onDeselect: {
                            if selectedCorner == index {
                                selectedCorner = nil
                            }
                        }
                    )
                }
            }
        }
    }
}

struct DraggableCorner: View {
    @Binding var position: CGPoint
    let isSelected: Bool
    let imageSize: CGSize
    let onSelect: () -> Void
    let onDeselect: () -> Void

    var body: some View {
        Circle()
            .fill(isSelected ? Color.appPrimary : Color.white)
            .frame(width: 30, height: 30)
            .overlay(
                Circle()
                    .stroke(Color.appPrimary, lineWidth: 2)
            )
            .position(position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        onSelect()
                        let newX = min(max(value.location.x, 0), imageSize.width)
                        let newY = min(max(value.location.y, 0), imageSize.height)
                        position = CGPoint(x: newX, y: newY)
                    }
                    .onEnded { _ in
                        onDeselect()
                    }
            )
    }
}

#Preview {
    PerspectiveCorrectionView(
        image: UIImage(systemName: "photo")!,
        onApply: { _ in }
    )
}
