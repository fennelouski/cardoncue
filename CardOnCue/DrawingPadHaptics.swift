import UIKit
import Combine

/// Manages haptic feedback for the drawing pad
class DrawingPadHaptics: ObservableObject {
    static let shared = DrawingPadHaptics()
    
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "drawingPad_hapticsEnabled")
        }
    }
    
    @Published var intensity: HapticIntensity {
        didSet {
            UserDefaults.standard.set(intensity.rawValue, forKey: "drawingPad_hapticsIntensity")
        }
    }
    
    private var impactGenerator: UIImpactFeedbackGenerator?
    private var selectionGenerator: UISelectionFeedbackGenerator?
    private var notificationGenerator: UINotificationFeedbackGenerator?
    
    enum HapticIntensity: String, CaseIterable {
        case light = "light"
        case medium = "medium"
        case heavy = "heavy"
        
        var style: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .light:
                return .light
            case .medium:
                return .medium
            case .heavy:
                return .heavy
            }
        }
    }
    
    private init() {
        // Load preferences
        self.enabled = UserDefaults.standard.bool(forKey: "drawingPad_hapticsEnabled", defaultValue: true)
        
        if let intensityRaw = UserDefaults.standard.string(forKey: "drawingPad_hapticsIntensity"),
           let intensity = HapticIntensity(rawValue: intensityRaw) {
            self.intensity = intensity
        } else {
            self.intensity = .medium
        }
        
        // Prepare generators
        prepareGenerators()
    }
    
    private func prepareGenerators() {
        impactGenerator = UIImpactFeedbackGenerator(style: intensity.style)
        impactGenerator?.prepare()
        
        selectionGenerator = UISelectionFeedbackGenerator()
        selectionGenerator?.prepare()
        
        notificationGenerator = UINotificationFeedbackGenerator()
        notificationGenerator?.prepare()
    }
    
    /// Trigger haptic when tool changes
    func toolChanged() {
        guard enabled else { return }
        selectionGenerator?.selectionChanged()
        selectionGenerator?.prepare()
    }
    
    /// Trigger haptic when stroke starts
    func strokeStarted() {
        guard enabled else { return }
        impactGenerator?.impactOccurred(intensity: 0.3)
        impactGenerator?.prepare()
    }
    
    /// Trigger haptic when stroke ends
    func strokeEnded() {
        guard enabled else { return }
        impactGenerator?.impactOccurred(intensity: 0.5)
        impactGenerator?.prepare()
    }
    
    /// Trigger haptic for undo/redo actions
    func undoRedo() {
        guard enabled else { return }
        selectionGenerator?.selectionChanged()
        selectionGenerator?.prepare()
    }
    
    /// Trigger haptic when shape is placed
    func shapePlaced() {
        guard enabled else { return }
        impactGenerator?.impactOccurred(intensity: 0.6)
        impactGenerator?.prepare()
    }
    
    /// Trigger haptic when stamp is placed
    func stampPlaced() {
        guard enabled else { return }
        impactGenerator?.impactOccurred(intensity: 0.7)
        impactGenerator?.prepare()
    }
    
    /// Trigger haptic for settings changes
    func settingsChanged() {
        guard enabled else { return }
        selectionGenerator?.selectionChanged()
        selectionGenerator?.prepare()
    }
    
    /// Update intensity and recreate generators
    func updateIntensity(_ newIntensity: HapticIntensity) {
        intensity = newIntensity
        prepareGenerators()
    }
}

// Helper extension for UserDefaults with default values
extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }
}

