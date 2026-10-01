import SwiftUI
import PencilKit

struct DrawingPadSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var haptics = DrawingPadHaptics.shared

    @AppStorage("drawingPad_defaultTool") private var defaultTool: String = "pen"
    @AppStorage("drawingPad_defaultColor") private var defaultColorHex: String = "#007AFF"
    @AppStorage("drawingPad_defaultWidth") private var defaultWidth: Double = 5.0
    @AppStorage("drawingPad_showGrid") private var showGrid: Bool = false
    @AppStorage("drawingPad_pressureSensitivity") private var pressureSensitivity: Bool = true

    @State private var selectedColor: Color = .appBlue
    @State private var hasLoadedColor = false
    @State private var activeSection: DrawingSettingsSection = .tools
    @State private var path: [DrawingSettingsSection] = []

    var body: some View {
        if #available(iOS 18.0, *) {
            settingsPanel.presentationSizing(.page)
        } else {
            settingsPanel
        }
    }

    private var settingsPanel: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width >= 760
            NavigationStack(path: $path) {
                VStack(spacing: 0) {
                    if isWide {
                        HStack(spacing: 0) {
                            sectionList(isWide: true)
                                .frame(width: dynamicTypeSize.isAccessibilitySize ? 320 : 240)
                            Divider()
                            settingsForm(activeSection)
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        sectionList(isWide: false)
                    }
                }
                .navigationTitle("Drawing Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { if path.isEmpty { doneToolbar } }
                .navigationDestination(for: DrawingSettingsSection.self) { section in
                    settingsForm(section)
                        .navigationTitle(section.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { doneToolbar }
                }
            }
            .onChange(of: isWide) { wasWide, nowWide in
                if nowWide {
                    if let visibleSection = path.last { activeSection = visibleSection }
                    path.removeAll()
                } else if wasWide && path.isEmpty {
                    path = [activeSection]
                }
            }
        }
        .tint(settingsTint)
        .onAppear {
            guard !hasLoadedColor else { return }
            hasLoadedColor = true
            selectedColor = Color.fromHex(defaultColorHex) ?? .appBlue
        }
        .onChange(of: path) { _, newPath in
            if let visibleSection = newPath.last { activeSection = visibleSection }
        }
        .onChange(of: selectedColor) { _, newColor in
            if let hex = newColor.toHex() { defaultColorHex = hex }
        }
        .onChange(of: haptics.enabled) { _, _ in haptics.settingsChanged() }
        .onChange(of: haptics.intensity) { _, _ in haptics.settingsChanged() }
    }

    private var sidebarSelection: Binding<DrawingSettingsSection?> {
        Binding(get: { activeSection }, set: { if let section = $0 { activeSection = section } })
    }

    private var doneToolbar: some ToolbarContent {
        ToolbarItem(id: "drawing-settings-done", placement: .confirmationAction) {
            Button("Done") { dismiss() }
        }
    }

    private func sectionList(isWide: Bool) -> some View {
        Group {
            if isWide {
                List(selection: sidebarSelection) {
                    ForEach(DrawingSettingsSection.allCases) { section in
                        sectionLabel(section, isSelected: activeSection == section).tag(section)
                    }
                }
            } else {
                List {
                    ForEach(DrawingSettingsSection.allCases) { section in
                        NavigationLink(value: section) { sectionLabel(section) }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(settingsBackground)
    }

    private func sectionLabel(_ section: DrawingSettingsSection, isSelected: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if !dynamicTypeSize.isAccessibilitySize { sectionSymbol(section, isSelected: isSelected) }
            VStack(alignment: .leading, spacing: 8) {
                if dynamicTypeSize.isAccessibilitySize { sectionSymbol(section, isSelected: isSelected) }
                Text(section.title)
                    .font(.headline)
                    .foregroundStyle(isSelected ? selectedForeground : Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
        .accessibilityIdentifier("drawing-settings-section-\(section.rawValue)")
    }

    private func sectionSymbol(_ section: DrawingSettingsSection, isSelected: Bool) -> some View {
        Image(systemName: section.symbol)
            .foregroundStyle(isSelected ? selectedForeground : section.color)
            .accessibilityHidden(true)
    }

    private var settingsTint: Color {
        colorScheme == .dark ? .appBlue : Color(red: 9.0 / 255, green: 110.0 / 255, blue: 134.0 / 255)
    }

    private var selectedForeground: Color {
        colorScheme == .dark ? Color(red: 0.04, green: 0.14, blue: 0.18) : .white
    }

    private var settingsBackground: some View {
        LinearGradient(colors: [Color(.systemGroupedBackground), Color.appBlue.opacity(0.08)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    private func settingsForm(_ section: DrawingSettingsSection) -> some View {
        Form {
            switch section {
            case .tools:
                previewSection
                Section {
                    Picker("Default Tool", selection: $defaultTool) {
                        Text("Pen").tag("pen")
                        Text("Marker").tag("marker")
                        Text("Pencil").tag("pencil")
                        Text("Eraser").tag("eraser")
                    }
                    ColorPicker("Default Color", selection: $selectedColor)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Line Width: \(Int(defaultWidth))")
                        Slider(value: $defaultWidth, in: 1...20, step: 1)
                            .accessibilityLabel("Default line width")
                            .accessibilityValue("\(Int(defaultWidth))")
                    }
                } header: {
                    Text("Tools")
                }
            case .canvas:
                previewSection
                Section {
                    Toggle("Show Grid", isOn: $showGrid)
                    Toggle("Pressure Sensitivity", isOn: $pressureSensitivity)
                } header: {
                    Text("Canvas")
                } footer: {
                    Text("Pressure sensitivity doesn't affect strokes yet.")
                }
            case .feedback:
                Section("Haptics") {
                    Toggle("Enable Haptics", isOn: $haptics.enabled)
                    if haptics.enabled {
                        Picker("Intensity", selection: Binding(
                            get: { haptics.intensity },
                            set: { haptics.updateIntensity($0) }
                        )) {
                            ForEach(DrawingPadHaptics.HapticIntensity.allCases, id: \.self) { intensity in
                                Text(intensity.rawValue.capitalized).tag(intensity)
                            }
                        }
                    }
                }
            case .about:
                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                } header: {
                    Text("About")
                } footer: {
                    Text("Drawing preferences are saved on this device.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .background(settingsBackground)
    }

    private var previewSection: some View {
        Section {
            DrawingDefaultsPreview(tool: previewTool, color: selectedColor,
                                   width: CGFloat(defaultWidth), showGrid: showGrid)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    private var previewTool: DrawingTool {
        switch defaultTool {
        case "marker": .marker
        case "pencil": .pencil
        case "eraser": .eraser
        default: .pen
        }
    }
}

private enum DrawingSettingsSection: String, CaseIterable, Identifiable {
    case tools, canvas, feedback, about
    var id: Self { self }

    var title: String {
        switch self {
        case .tools: "Tools"
        case .canvas: "Canvas"
        case .feedback: "Feedback"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .tools: "pencil.tip"
        case .canvas: "square.grid.3x3"
        case .feedback: "hand.tap"
        case .about: "info.circle"
        }
    }

    var color: Color {
        switch self {
        case .tools: .appBlue
        case .canvas: .appGreen
        case .feedback: .orange
        case .about: .secondary
        }
    }
}

private struct DrawingDefaultsPreview: View {
    let tool: DrawingTool
    let color: Color
    let width: CGFloat
    let showGrid: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(uiImage: sampleImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(tool == .eraser ? "Eraser removes strokes; it adds no ink." : "\(tool.displayName) · Width \(Int(width)) · Stroke sample")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Defaults for the next drawing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("drawing-settings-preview")
    }

    private var sampleImage: UIImage {
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 140)
        let drawing: PKDrawing
        if let inkTool = tool.toPKTool(color: UIColor(color), width: width) as? PKInkingTool {
            let points = (0...40).map { index in
                let progress = CGFloat(index) / 40
                return PKStrokePoint(location: CGPoint(x: 24 + progress * 272,
                                                      y: 70 + sin(progress * .pi * 2) * 24),
                                     timeOffset: Double(index) / 60,
                                     size: CGSize(width: inkTool.width, height: inkTool.width),
                                     opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
            }
            let path = PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0))
            drawing = PKDrawing(strokes: [PKStroke(ink: inkTool.ink, path: path)])
        } else {
            drawing = PKDrawing()
        }
        return UIGraphicsImageRenderer(size: bounds.size).image { context in
            UIColor.white.setFill()
            context.fill(bounds)
            drawing.image(from: bounds, scale: 2).draw(in: bounds)
            if showGrid {
                let grid = UIBezierPath()
                for x in stride(from: CGFloat(0), to: bounds.width, by: 20) {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: bounds.height))
                }
                for y in stride(from: CGFloat(0), to: bounds.height, by: 20) {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: bounds.width, y: y))
                }
                UIColor.gray.withAlphaComponent(0.3).setStroke()
                grid.lineWidth = 0.5
                grid.stroke()
            }
        }
    }
}

#Preview {
    DrawingPadSettingsView()
}
