import Foundation
import AVFoundation
import Combine

/// Manages camera permission state for the app
class CameraPermissionManager: ObservableObject {
    @Published var permissionStatus: PermissionStatus = .notDetermined

    enum PermissionStatus {
        case notDetermined
        case granted
        case denied
        case restricted

        var isGranted: Bool {
            return self == .granted
        }
    }

    init() {
        checkPermissionStatus()
    }

    /// Check current camera permission status
    func checkPermissionStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        DispatchQueue.main.async {
            switch status {
            case .authorized:
                self.permissionStatus = .granted
            case .notDetermined:
                self.permissionStatus = .notDetermined
            case .denied:
                self.permissionStatus = .denied
            case .restricted:
                self.permissionStatus = .restricted
            @unknown default:
                self.permissionStatus = .notDetermined
            }
        }
    }

    /// Request camera permission
    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.checkPermissionStatus()
                completion(granted)
            }
        }
    }

    /// Mark permission as denied (when user explicitly declines)
    func markAsDenied() {
        permissionStatus = .denied
    }
}
