import SwiftUI

struct DrawingPadSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var haptics = DrawingPadHaptics.shared
    
    @AppStorage("drawingPad_defaultTool") private var defaultTool: String = "pen"
    @AppStorage("drawingPad_defaultColor") private var defaultColorHex: String = "#007AFF"
    @AppStorage("drawingPad_defaultWidth") private var defaultWidth: Double = 5.0
    @AppStorage("drawingPad_showGrid") private var showGrid: Bool = false
    @AppStorage("drawingPad_pressureSensitivity") private var pressureSensitivity: Bool = true
    
    @State private var selectedColor: Color = .appBlue
    
    var body: some View {
        NavigationStack {
            Form {
                // Haptics Section
                Section("Haptics") {
                    Toggle("Enable Haptics", isOn: $haptics.enabled)
                        .onChange(of: haptics.enabled) { _, _ in
                            haptics.settingsChanged()
                        }
                    
                    if haptics.enabled {
                        Picker("Intensity", selection: Binding(
                            get: { haptics.intensity },
                            set: { haptics.updateIntensity($0) }
                        )) {
                            ForEach(DrawingPadHaptics.HapticIntensity.allCases, id: \.self) { intensity in
                                Text(intensity.rawValue.capitalized).tag(intensity)
                            }
                        }
                        .onChange(of: haptics.intensity) { _, _ in
                            haptics.settingsChanged()
                        }
                    }
                }
                
                // Defaults Section
                Section("Default Settings") {
                    Picker("Default Tool", selection: $defaultTool) {
                        Text("Pen").tag("pen")
                        Text("Marker").tag("marker")
                        Text("Pencil").tag("pencil")
                        Text("Eraser").tag("eraser")
                    }
                    
                    ColorPicker("Default Color", selection: $selectedColor)
                        .onChange(of: selectedColor) { _, newColor in
                            if let hex = newColor.toHex() {
                                defaultColorHex = hex
                            }
                        }
                        .onAppear {
                            selectedColor = Color.fromHex(defaultColorHex) ?? .appBlue
                        }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Line Width: \(Int(defaultWidth))")
                        Slider(value: $defaultWidth, in: 1...20, step: 1)
                    }
                }
                
                // Drawing Options Section
                Section("Drawing Options") {
                    Toggle("Show Grid", isOn: $showGrid)
                    Toggle("Pressure Sensitivity", isOn: $pressureSensitivity)
                }
                
                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("Customize your drawing experience with these settings.")
                }
            }
            .navigationTitle("Drawing Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.appBlue)
                }
            }
        }
    }
}

#Preview {
    DrawingPadSettingsView()
}

