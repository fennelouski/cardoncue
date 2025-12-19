import SwiftUI
import PencilKit

struct DrawingPadView: View {
    @Environment(\.dismiss) private var dismiss
    let card: CardModel
    let onComplete: (CardIcon) -> Void
    
    @State private var canvas = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var selectedTool: DrawingTool = .pen
    @State private var drawingColor: Color = .appBlue
    @State private var lineWidth: CGFloat = 5
    @State private var backgroundColor: Color = .white
    @State private var showGrid: Bool = false
    @State private var showingSettings = false
    @State private var canUndo = false
    @State private var canRedo = false
    @State private var existingDrawing: PKDrawing?
    @State private var previewImage: UIImage?
    @State private var undoRedoTimer: Timer?
    
    @StateObject private var haptics = DrawingPadHaptics.shared
    
    // Preset colors
    private let presetColors: [Color] = [
        .appBlue, .appGreen, .red, .orange, .yellow,
        .purple, .pink, .cyan, .mint, .indigo, .black, .gray
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top toolbar - Undo/Redo, Clear, Settings
                HStack(spacing: 12) {
                    // Undo button
                    Button(action: undo) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 18))
                            .foregroundColor(canUndo ? .appBlue : .gray)
                            .frame(width: 44, height: 44)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .disabled(!canUndo)
                    
                    // Redo button
                    Button(action: redo) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 18))
                            .foregroundColor(canRedo ? .appBlue : .gray)
                            .frame(width: 44, height: 44)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .disabled(!canRedo)
                    
                    Spacer()
                    
                    // Clear button
                    Button(action: clearDrawing) {
                        Image(systemName: "trash")
                            .font(.system(size: 18))
                            .foregroundColor(.red)
                            .frame(width: 44, height: 44)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Settings button
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(.appBlue)
                            .frame(width: 44, height: 44)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                
                // Tool selection - horizontal scrollable
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Basic tools
                        ToolButton(tool: .pen, selectedTool: $selectedTool, action: { selectedTool = .pen })
                        ToolButton(tool: .marker, selectedTool: $selectedTool, action: { selectedTool = .marker })
                        ToolButton(tool: .pencil, selectedTool: $selectedTool, action: { selectedTool = .pencil })
                        ToolButton(tool: .eraser, selectedTool: $selectedTool, action: { selectedTool = .eraser })
                        
                        // Shape tools
                        ForEach(ShapeType.allCases, id: \.self) { shapeType in
                            ToolButton(
                                tool: .shape(shapeType),
                                selectedTool: $selectedTool,
                                action: { selectedTool = .shape(shapeType) }
                            )
                        }
                        
                        // Symmetry tools
                        ToolButton(
                            tool: .symmetry(.horizontal),
                            selectedTool: $selectedTool,
                            action: { selectedTool = .symmetry(.horizontal) }
                        )
                        ToolButton(
                            tool: .symmetry(.vertical),
                            selectedTool: $selectedTool,
                            action: { selectedTool = .symmetry(.vertical) }
                        )
                        ToolButton(
                            tool: .symmetry(.radial(segments: 6)),
                            selectedTool: $selectedTool,
                            action: { selectedTool = .symmetry(.radial(segments: 6)) }
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.05))
                
                // Color and width controls
                HStack(spacing: 16) {
                    // Preset colors
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presetColors, id: \.description) { color in
                                Button(action: {
                                    drawingColor = color
                                    haptics.toolChanged()
                                }) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(drawingColor == color ? Color.primary : Color.clear, lineWidth: 2)
                                        )
                                }
                            }
                            
                            // Custom color picker
                            ColorPicker("", selection: $drawingColor)
                                .frame(width: 32, height: 32)
                                .background(Color.gray.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Line width
                    VStack(spacing: 4) {
                        Text("Width")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Slider(value: $lineWidth, in: 1...20)
                            .frame(width: 120)
                    }
                    
                    // Background color
                    VStack(spacing: 4) {
                        Text("BG")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        ColorPicker("", selection: $backgroundColor)
                            .frame(width: 32, height: 32)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    // Grid toggle
                    Button(action: {
                        showGrid.toggle()
                        haptics.settingsChanged()
                    }) {
                        Image(systemName: showGrid ? "grid" : "grid.circle")
                            .font(.system(size: 18))
                            .foregroundColor(showGrid ? .appBlue : .gray)
                            .frame(width: 44, height: 44)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                
                // Canvas with preview
                ZStack {
                    DrawingCanvasView(
                        canvas: $canvas,
                        toolPicker: $toolPicker,
                        selectedTool: selectedTool,
                        drawingColor: drawingColor,
                        lineWidth: lineWidth,
                        backgroundColor: backgroundColor,
                        showGrid: showGrid,
                        onDrawingChanged: {
                            updateUndoRedoState()
                            updatePreview()
                        }
                    )
                    
                    // Preview in corner
                    if let previewImage = previewImage {
                        VStack {
                            HStack {
                                Spacer()
                                Image(uiImage: previewImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .shadow(radius: 4)
                                    .padding()
                            }
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Draw Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.appBlue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveDrawing()
                    }
                    .foregroundColor(.appBlue)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingSettings) {
                DrawingPadSettingsView()
            }
            .onAppear {
                loadDefaultSettings()
                loadExistingDrawing()
                setupCanvas()
                updateUndoRedoState()
            }
            .onChange(of: selectedTool) { _, _ in
                updateTool()
                haptics.toolChanged()
            }
            .onChange(of: drawingColor) { _, _ in
                updateTool()
            }
            .onChange(of: lineWidth) { _, _ in
                updateTool()
            }
            .onDisappear {
                undoRedoTimer?.invalidate()
            }
        }
    }
    
    private func loadDefaultSettings() {
        // Load default tool from settings
        if let defaultToolRaw = UserDefaults.standard.string(forKey: "drawingPad_defaultTool") {
            switch defaultToolRaw {
            case "pen":
                selectedTool = .pen
            case "marker":
                selectedTool = .marker
            case "pencil":
                selectedTool = .pencil
            case "eraser":
                selectedTool = .eraser
            default:
                break
            }
        }
        
        // Load default color
        if let colorHex = UserDefaults.standard.string(forKey: "drawingPad_defaultColor"),
           let color = Color.fromHex(colorHex) {
            drawingColor = color
        }
        
        // Load default width
        if let defaultWidth = UserDefaults.standard.object(forKey: "drawingPad_defaultWidth") as? Double, defaultWidth > 0 {
            lineWidth = CGFloat(defaultWidth)
        }
        
        // Load grid preference
        showGrid = UserDefaults.standard.bool(forKey: "drawingPad_showGrid")
    }
    
    private func loadExistingDrawing() {
        if let existing = CardImageStorageService.shared.loadDrawingData(cardId: card.id) {
            existingDrawing = existing
            canvas.drawing = existing
            updatePreview()
        }
    }
    
    private func setupCanvas() {
        canvas.backgroundColor = UIColor(backgroundColor)
        canvas.drawingPolicy = .anyInput
        canvas.isOpaque = false
        
        // Set up tool
        updateTool()
        
        // Show tool picker
        toolPicker.setVisible(true, forFirstResponder: canvas)
        toolPicker.addObserver(canvas)
        canvas.becomeFirstResponder()
        
        // Set up periodic check for undo/redo state
        undoRedoTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateUndoRedoState()
        }
    }
    
    private func updateTool() {
        let tool = selectedTool.toPKTool(color: UIColor(drawingColor), width: lineWidth)
        canvas.tool = tool
    }
    
    private func undo() {
        canvas.undoManager?.undo()
        haptics.undoRedo()
        updateUndoRedoState()
    }
    
    private func redo() {
        canvas.undoManager?.redo()
        haptics.undoRedo()
        updateUndoRedoState()
    }
    
    private func clearDrawing() {
        canvas.drawing = PKDrawing()
        haptics.settingsChanged()
        updateUndoRedoState()
        updatePreview()
    }
    
    private func updateUndoRedoState() {
        canUndo = canvas.undoManager?.canUndo ?? false
        canRedo = canvas.undoManager?.canRedo ?? false
    }
    
    private func updatePreview() {
        let drawing = canvas.drawing
        let bounds = drawing.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 200, height: 200) : drawing.bounds.insetBy(dx: -10, dy: -10)
        let imageRect = CGRect(origin: .zero, size: CGSize(width: 200, height: 200))
        
        let renderer = UIGraphicsImageRenderer(size: imageRect.size)
        previewImage = renderer.image { context in
            UIColor(backgroundColor).setFill()
            context.fill(imageRect)
            
            if !drawing.bounds.isEmpty {
                let scale = min(
                    imageRect.width / bounds.width,
                    imageRect.height / bounds.height
                )
                context.cgContext.scaleBy(x: scale, y: scale)
                context.cgContext.translateBy(x: -bounds.minX + 10, y: -bounds.minY + 10)
                drawing.image(from: bounds, scale: 2.0).draw(in: bounds)
            }
        }
    }
    
    private func saveDrawing() {
        // Render drawing as image
        let drawing = canvas.drawing
        let bounds = drawing.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 200, height: 200) : drawing.bounds.insetBy(dx: -10, dy: -10)
        let imageRect = CGRect(origin: .zero, size: CGSize(width: 200, height: 200))
        
        let renderer = UIGraphicsImageRenderer(size: imageRect.size)
        let image = renderer.image { context in
            // Fill background
            UIColor(backgroundColor).setFill()
            context.fill(imageRect)
            
            if !drawing.bounds.isEmpty {
                // Scale drawing to fit
                let scale = min(
                    imageRect.width / bounds.width,
                    imageRect.height / bounds.height
                )
                context.cgContext.scaleBy(x: scale, y: scale)
                context.cgContext.translateBy(x: -bounds.minX + 10, y: -bounds.minY + 10)
                
                // Draw
                drawing.image(from: bounds, scale: 2.0).draw(in: bounds)
            }
        }
        
        Task {
            do {
                // Save both image and drawing data
                let iconURL = try CardImageStorageService.shared.saveIconImage(image, cardId: card.id)
                _ = try CardImageStorageService.shared.saveDrawingData(drawing, cardId: card.id)
                
                let icon = CardIcon.drawing(iconURL.path)
                await MainActor.run {
                    onComplete(icon)
                }
            } catch {
                print("Failed to save drawing: \(error)")
            }
        }
    }
}

// Tool button component
struct ToolButton: View {
    let tool: DrawingTool
    @Binding var selectedTool: DrawingTool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: tool.iconName)
                    .font(.system(size: 20))
                Text(tool.displayName)
                    .font(.caption2)
            }
            .foregroundColor(selectedTool == tool ? .white : .appBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedTool == tool ? Color.appBlue : Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
    }
}

// Enhanced canvas view
struct DrawingCanvasView: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    let selectedTool: DrawingTool
    let drawingColor: Color
    let lineWidth: CGFloat
    let backgroundColor: Color
    let showGrid: Bool
    let onDrawingChanged: () -> Void
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvas.backgroundColor = UIColor(backgroundColor)
        canvas.drawingPolicy = .anyInput
        canvas.isOpaque = false
        
        // Set up tool
        let tool = selectedTool.toPKTool(color: UIColor(drawingColor), width: lineWidth)
        canvas.tool = tool
        
        // Show tool picker
        toolPicker.setVisible(true, forFirstResponder: canvas)
        toolPicker.addObserver(canvas)
        
        // Add delegate for drawing changes
        canvas.delegate = context.coordinator
        
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.backgroundColor = UIColor(backgroundColor)
        let tool = selectedTool.toPKTool(color: UIColor(drawingColor), width: lineWidth)
        uiView.tool = tool
        
        // Update grid overlay if needed
        updateGridOverlay(on: uiView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }
    
    private func updateGridOverlay(on canvasView: PKCanvasView) {
        // Remove existing grid overlays
        canvasView.subviews.forEach { subview in
            if subview.tag == 999 { // Tag for grid overlay
                subview.removeFromSuperview()
            }
        }
        
        if showGrid {
            let gridView = createGridView(frame: canvasView.bounds)
            gridView.tag = 999
            gridView.isUserInteractionEnabled = false
            canvasView.addSubview(gridView)
        }
    }
    
    private func createGridView(frame: CGRect) -> UIView {
        let gridView = UIView(frame: frame)
        gridView.backgroundColor = .clear
        
        let gridLayer = CAShapeLayer()
        gridLayer.strokeColor = UIColor.gray.withAlphaComponent(0.3).cgColor
        gridLayer.lineWidth = 0.5
        
        let path = UIBezierPath()
        let spacing: CGFloat = 20
        
        // Vertical lines
        var x: CGFloat = 0
        while x < frame.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: frame.height))
            x += spacing
        }
        
        // Horizontal lines
        var y: CGFloat = 0
        while y < frame.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: frame.width, y: y))
            y += spacing
        }
        
        gridLayer.path = path.cgPath
        gridView.layer.addSublayer(gridLayer)
        
        return gridView
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        let onDrawingChanged: () -> Void
        
        init(onDrawingChanged: @escaping () -> Void) {
            self.onDrawingChanged = onDrawingChanged
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChanged()
        }
    }
}
