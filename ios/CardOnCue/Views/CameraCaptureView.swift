import SwiftUI
import UIKit

enum CaptureMode {
    case barcodeImage
    case frontCardImage
}

struct CameraCaptureView: View {
    @Environment(\.dismiss) var dismiss
    let mode: CaptureMode
    let onImageCaptured: (UIImage) -> Void

    @State private var showingImagePicker = false
    @State private var showingSourceSelection = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: iconName)
                        .font(.system(size: 50))
                        .foregroundColor(.appPrimary)
                }

                VStack(spacing: 12) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.appBlue)

                    Text(subtitle)
                        .font(.body)
                        .foregroundColor(.appGreen)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: {
                        showingSourceSelection = true
                    }) {
                        HStack {
                            Image(systemName: "camera")
                                .font(.headline)
                            Text("Take Photo")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.appPrimary)
                        .cornerRadius(12)
                    }

                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundColor(.appBlue)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .actionSheet(isPresented: $showingSourceSelection) {
                ActionSheet(
                    title: Text("Select Photo Source"),
                    buttons: [
                        .default(Text("Camera")) {
                            showingImagePicker = true
                        },
                        .default(Text("Photo Library")) {
                            showingImagePicker = true
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView(onImageSelected: { image in
                    onImageCaptured(image)
                    dismiss()
                })
            }
        }
    }

    private var iconName: String {
        switch mode {
        case .barcodeImage:
            return "barcode.viewfinder"
        case .frontCardImage:
            return "creditcard"
        }
    }

    private var title: String {
        switch mode {
        case .barcodeImage:
            return "Capture Barcode"
        case .frontCardImage:
            return "Capture Card Front"
        }
    }

    private var subtitle: String {
        switch mode {
        case .barcodeImage:
            return "Take a clear photo of your card's barcode. Make sure it's well-lit and in focus."
        case .frontCardImage:
            return "Take a photo of the front of your card for easy identification."
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .barcodeImage:
            return "Add Barcode Image"
        case .frontCardImage:
            return "Add Card Image"
        }
    }
}

struct ImagePickerView: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .rear
        picker.showsCameraControls = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageSelected: (UIImage) -> Void

        init(onImageSelected: @escaping (UIImage) -> Void) {
            self.onImageSelected = onImageSelected
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImageSelected(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    CameraCaptureView(mode: .barcodeImage) { _ in }
}
