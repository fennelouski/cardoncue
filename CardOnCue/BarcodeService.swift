import Foundation
@preconcurrency import AVFoundation
import Vision
import Combine
import UIKit

/// Result of a barcode scan
struct ScannedBarcode {
    let type: BarcodeType
    let payload: String
    let rawImage: UIImage?
    let confidence: Float
}

/// Barcode service errors
enum BarcodeError: LocalizedError {
    case cameraNotAvailable
    case permissionDenied
    case scanFailed
    case invalidPayload
    case renderFailed(BarcodeType)

    var errorDescription: String? {
        switch self {
        case .cameraNotAvailable:
            return "Camera is not available on this device"
        case .permissionDenied:
            return "Camera permission denied. Please enable in Settings."
        case .scanFailed:
            return "Failed to scan barcode. Please try again."
        case .invalidPayload:
            return "Invalid barcode payload"
        case .renderFailed(let type):
            return "Failed to render \(type.displayName)"
        }
    }
}

/// Barcode scanning and rendering service
@MainActor
class BarcodeService: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var lastError: Error?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var scanCompletion: ((Result<ScannedBarcode, Error>) -> Void)?

    // MARK: - Scanning

    /// Request camera permission
    func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    /// Start barcode scanning session
    func startScanning(completion: @escaping (Result<ScannedBarcode, Error>) -> Void) throws -> AVCaptureVideoPreviewLayer {
        guard !isScanning else {
            throw BarcodeError.scanFailed
        }

        // Check permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status == .authorized else {
            throw BarcodeError.permissionDenied
        }

        // Setup capture session
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            throw BarcodeError.cameraNotAvailable
        }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            throw BarcodeError.cameraNotAvailable
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            throw BarcodeError.cameraNotAvailable
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .qr,
                .code128,
                .pdf417,
                .aztec,
                .ean13,
                .upce,
                .code39,
                .itf14
            ]
        } else {
            throw BarcodeError.cameraNotAvailable
        }

        // Create preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill

        // Store references
        self.captureSession = session
        self.previewLayer = previewLayer
        self.scanCompletion = completion
        self.isScanning = true

        // Start session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return previewLayer
    }

    /// Stop scanning session
    func stopScanning() {
        captureSession?.stopRunning()
        captureSession = nil
        previewLayer = nil
        scanCompletion = nil
        isScanning = false
    }

    private func mapMetadataType(_ type: AVMetadataObject.ObjectType) -> BarcodeType? {
        switch type {
        case .qr: return .qr
        case .code128: return .code128
        case .pdf417: return .pdf417
        case .aztec: return .aztec
        case .ean13: return .ean13
        case .upce: return .upcA
        case .code39: return .code39
        case .itf14: return .itf
        default: return nil
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension BarcodeService: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let payload = metadataObject.stringValue else {
            return
        }

        Task { @MainActor in
            // Stop scanning
            self.stopScanning()

            // Map type
            guard let barcodeType = mapMetadataType(metadataObject.type) else {
                scanCompletion?(.failure(BarcodeError.scanFailed))
                return
            }

            // Create result
            let scanned = ScannedBarcode(
                type: barcodeType,
                payload: payload,
                rawImage: nil, // TODO: Capture frame as UIImage
                confidence: 1.0
            )

            // Call completion
            scanCompletion?(.success(scanned))
        }
    }
}

// MARK: - Rendering

extension BarcodeService {
    /// Render barcode image using CoreImage
    func renderBarcode(payload: String, type: BarcodeType, size: CGSize) throws -> UIImage {
        // Use CoreImage filter if available
        if let filterName = type.coreImageFilterName {
            return try renderWithCoreImage(payload: payload, filterName: filterName, size: size)
        }

        // Fallback: not supported by CoreImage
        throw BarcodeError.renderFailed(type)
    }

    private func renderWithCoreImage(payload: String, filterName: String, size: CGSize) throws -> UIImage {
        guard let data = payload.data(using: .ascii) else {
            throw BarcodeError.invalidPayload
        }

        guard let filter = CIFilter(name: filterName) else {
            throw BarcodeError.renderFailed(.qr)
        }

        filter.setValue(data, forKey: "inputMessage")

        // For QR codes, set correction level
        if filterName == "CIQRCodeGenerator" {
            filter.setValue("M", forKey: "inputCorrectionLevel")
        }

        guard let outputImage = filter.outputImage else {
            throw BarcodeError.renderFailed(.qr)
        }

        // Scale to desired size
        let scaleX = size.width / outputImage.extent.width
        let scaleY = size.height / outputImage.extent.height
        let scale = min(scaleX, scaleY)

        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)

        // Render to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw BarcodeError.renderFailed(.qr)
        }

        return UIImage(cgImage: cgImage)
    }
}
