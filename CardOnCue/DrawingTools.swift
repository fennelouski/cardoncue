import Foundation
import PencilKit

/// Drawing tool types available in the drawing pad
enum DrawingTool: Equatable {
    case pen
    case marker
    case pencil
    case eraser
    case shape(ShapeType)
    case stamp(StampType)
    case symmetry(SymmetryMode)
    
    var displayName: String {
        switch self {
        case .pen:
            return "Pen"
        case .marker:
            return "Marker"
        case .pencil:
            return "Pencil"
        case .eraser:
            return "Eraser"
        case .shape(let shapeType):
            return shapeType.displayName
        case .stamp(let stampType):
            return stampType.displayName
        case .symmetry(let mode):
            return mode.displayName
        }
    }
    
    var iconName: String {
        switch self {
        case .pen:
            return "pencil.tip"
        case .marker:
            return "pencil.tip.crop.circle"
        case .pencil:
            return "pencil"
        case .eraser:
            return "eraser"
        case .shape:
            return "square.on.circle"
        case .stamp:
            return "seal"
        case .symmetry:
            return "kaleidoscope"
        }
    }
}

/// Shape types for drawing
enum ShapeType: String, CaseIterable {
    case circle
    case rectangle
    case line
    case curve
    
    var displayName: String {
        switch self {
        case .circle:
            return "Circle"
        case .rectangle:
            return "Rectangle"
        case .line:
            return "Line"
        case .curve:
            return "Curve"
        }
    }
    
    var iconName: String {
        switch self {
        case .circle:
            return "circle"
        case .rectangle:
            return "rectangle"
        case .line:
            return "line.diagonal"
        case .curve:
            return "waveform.path"
        }
    }
}

/// Stamp types for quick placement
enum StampType: String, CaseIterable {
    case heart
    case star
    case checkmark
    case xmark
    case plus
    case minus
    case circle
    case square
    
    var displayName: String {
        switch self {
        case .heart:
            return "Heart"
        case .star:
            return "Star"
        case .checkmark:
            return "Check"
        case .xmark:
            return "X"
        case .plus:
            return "Plus"
        case .minus:
            return "Minus"
        case .circle:
            return "Circle"
        case .square:
            return "Square"
        }
    }
    
    var iconName: String {
        switch self {
        case .heart:
            return "heart.fill"
        case .star:
            return "star.fill"
        case .checkmark:
            return "checkmark.circle.fill"
        case .xmark:
            return "xmark.circle.fill"
        case .plus:
            return "plus.circle.fill"
        case .minus:
            return "minus.circle.fill"
        case .circle:
            return "circle.fill"
        case .square:
            return "square.fill"
        }
    }
}

/// Symmetry modes for kaleidoscope effects
enum SymmetryMode: Equatable {
    case none
    case horizontal
    case vertical
    case radial(segments: Int) // Kaleidoscope mode
    
    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .horizontal:
            return "Horizontal"
        case .vertical:
            return "Vertical"
        case .radial(let segments):
            return "Kaleidoscope (\(segments))"
        }
    }
    
    var iconName: String {
        switch self {
        case .none:
            return "1.square"
        case .horizontal:
            return "arrow.up.arrow.down"
        case .vertical:
            return "arrow.left.arrow.right"
        case .radial:
            return "kaleidoscope"
        }
    }
}

/// Helper to convert DrawingTool to PKTool
extension DrawingTool {
    func toPKTool(color: UIColor, width: CGFloat) -> PKTool {
        switch self {
        case .pen:
            return PKInkingTool(.pen, color: color, width: width)
        case .marker:
            return PKInkingTool(.marker, color: color, width: width)
        case .pencil:
            return PKInkingTool(.pencil, color: color, width: width)
        case .eraser:
            return PKEraserTool(.vector)
        case .shape, .stamp, .symmetry:
            // These require custom handling
            return PKInkingTool(.pen, color: color, width: width)
        }
    }
}

