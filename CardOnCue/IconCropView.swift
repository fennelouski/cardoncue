import SwiftUI

/// View for manually cropping/selecting an icon region from a card image
struct IconCropView: View {
    let image: UIImage
    let onCrop: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var cropRect = CGRect(x: 50, y: 50, width: 150, height: 150)
    @State private var imageSize: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Instructions
                    Text("Drag to select the logo/icon area")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()

                    // Image with crop overlay
                    GeometryReader { geometry in
                        ZStack {
                            // The card image
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .background(
                                    GeometryReader { imageGeometry in
                                        Color.clear
                                            .onAppear {
                                                imageSize = imageGeometry.size
                                                // Initialize crop rect in center
                                                let size = min(imageGeometry.size.width, imageGeometry.size.height) * 0.4
                                                cropRect = CGRect(
                                                    x: (imageGeometry.size.width - size) / 2,
                                                    y: (imageGeometry.size.height - size) / 2,
                                                    width: size,
                                                    height: size
                                                )
                                            }
                                    }
                                )

                            // Crop overlay
                            CropOverlay(
                                cropRect: $cropRect,
                                imageSize: imageSize
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding()

                    // Action buttons
                    HStack(spacing: 20) {
                        Button(action: onCancel) {
                            Text("Cancel")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.gray.opacity(0.5))
                                .cornerRadius(12)
                        }

                        Button(action: {
                            // Convert crop rect from view coordinates to image coordinates
                            let scale = image.size.width / imageSize.width
                            let imageCropRect = CGRect(
                                x: cropRect.origin.x * scale,
                                y: cropRect.origin.y * scale,
                                width: cropRect.width * scale,
                                height: cropRect.height * scale
                            )
                            onCrop(imageCropRect)
                        }) {
                            Text("Use This Icon")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.appBlue)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Select Icon")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

/// Crop selection overlay with draggable handles
struct CropOverlay: View {
    @Binding var cropRect: CGRect
    let imageSize: CGSize

    @State private var initialCropRect: CGRect = .zero

    var body: some View {
        ZStack {
            // Dim overlay outside crop area
            GeometryReader { geometry in
                // Top
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(height: cropRect.minY)

                // Bottom
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(height: geometry.size.height - cropRect.maxY)
                    .offset(y: cropRect.maxY)

                // Left
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: cropRect.minX, height: cropRect.height)
                    .offset(x: 0, y: cropRect.minY)

                // Right
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: geometry.size.width - cropRect.maxX, height: cropRect.height)
                    .offset(x: cropRect.maxX, y: cropRect.minY)
            }

            // Crop selection border
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)

            // Corner handles
            Group {
                // Top-left
                CropHandle()
                    .position(x: cropRect.minX, y: cropRect.minY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if initialCropRect == .zero {
                                    initialCropRect = cropRect
                                }
                                let newX = max(0, min(initialCropRect.maxX - 50, initialCropRect.minX + value.translation.width))
                                let newY = max(0, min(initialCropRect.maxY - 50, initialCropRect.minY + value.translation.height))
                                let newWidth = initialCropRect.maxX - newX
                                let newHeight = initialCropRect.maxY - newY
                                cropRect = CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
                            }
                            .onEnded { _ in
                                initialCropRect = .zero
                            }
                    )

                // Top-right
                CropHandle()
                    .position(x: cropRect.maxX, y: cropRect.minY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if initialCropRect == .zero {
                                    initialCropRect = cropRect
                                }
                                let newMaxX = max(initialCropRect.minX + 50, min(imageSize.width, initialCropRect.maxX + value.translation.width))
                                let newY = max(0, min(initialCropRect.maxY - 50, initialCropRect.minY + value.translation.height))
                                let newWidth = newMaxX - initialCropRect.minX
                                let newHeight = initialCropRect.maxY - newY
                                cropRect = CGRect(x: initialCropRect.minX, y: newY, width: newWidth, height: newHeight)
                            }
                            .onEnded { _ in
                                initialCropRect = .zero
                            }
                    )

                // Bottom-left
                CropHandle()
                    .position(x: cropRect.minX, y: cropRect.maxY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if initialCropRect == .zero {
                                    initialCropRect = cropRect
                                }
                                let newX = max(0, min(initialCropRect.maxX - 50, initialCropRect.minX + value.translation.width))
                                let newMaxY = max(initialCropRect.minY + 50, min(imageSize.height, initialCropRect.maxY + value.translation.height))
                                let newWidth = initialCropRect.maxX - newX
                                let newHeight = newMaxY - initialCropRect.minY
                                cropRect = CGRect(x: newX, y: initialCropRect.minY, width: newWidth, height: newHeight)
                            }
                            .onEnded { _ in
                                initialCropRect = .zero
                            }
                    )

                // Bottom-right
                CropHandle()
                    .position(x: cropRect.maxX, y: cropRect.maxY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if initialCropRect == .zero {
                                    initialCropRect = cropRect
                                }
                                let newMaxX = max(initialCropRect.minX + 50, min(imageSize.width, initialCropRect.maxX + value.translation.width))
                                let newMaxY = max(initialCropRect.minY + 50, min(imageSize.height, initialCropRect.maxY + value.translation.height))
                                let newWidth = newMaxX - initialCropRect.minX
                                let newHeight = newMaxY - initialCropRect.minY
                                cropRect = CGRect(x: initialCropRect.minX, y: initialCropRect.minY, width: newWidth, height: newHeight)
                            }
                            .onEnded { _ in
                                initialCropRect = .zero
                            }
                    )
            }

            // Center drag area (move entire crop rect)
            Rectangle()
                .fill(Color.clear)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if initialCropRect == .zero {
                                initialCropRect = cropRect
                            }
                            let newX = max(0, min(imageSize.width - initialCropRect.width, initialCropRect.minX + value.translation.width))
                            let newY = max(0, min(imageSize.height - initialCropRect.height, initialCropRect.minY + value.translation.height))
                            cropRect = CGRect(x: newX, y: newY, width: initialCropRect.width, height: initialCropRect.height)
                        }
                        .onEnded { _ in
                            initialCropRect = .zero
                        }
                )
        }
    }
}

/// Visual handle for crop corners
struct CropHandle: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 20, height: 20)
            .overlay(
                Circle()
                    .stroke(Color.appBlue, lineWidth: 2)
            )
    }
}

#Preview {
    IconCropView(
        image: UIImage(systemName: "photo")!,
        onCrop: { rect in
            print("Cropped: \(rect)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
