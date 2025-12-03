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
        case unavailable  // Camera not available on this platform (e.g., visionOS)

        var isGranted: Bool {
            return self == .granted
        }
    }

    /// Check if camera is available on this platform
    var isCameraAvailable: Bool {
        #if os(visionOS)
        return false
        #else
        return AVCaptureDevice.default(for: .video) != nil
        #endif
    }

    init() {
        checkPermissionStatus()
    }

    /// Check current camera permission status
    func checkPermissionStatus() {
        #if os(visionOS)
        DispatchQueue.main.async {
            self.permissionStatus = .unavailable
        }
        return
        #endif
        
        guard isCameraAvailable else {
            DispatchQueue.main.async {
                self.permissionStatus = .unavailable
            }
            return
        }
        
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
        #if os(visionOS)
        DispatchQueue.main.async {
            completion(false)
        }
        return
        #endif
        
        guard isCameraAvailable else {
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }
        
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
