import SwiftUI

struct AddCardSwipeableView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var rapidState = RapidScanningState()
    @State private var showingBatchLocationPicker = false

    var canScan: Bool

    private var pageCount: Int {
        canScan ? 3 : 2
    }

    var body: some View {
        ZStack {
            // Swipeable input methods
            TabView(selection: $currentPage) {
                // Page 1: Live Camera Scanner (if available)
                if canScan {
                    #if !os(visionOS)
                    BarcodeScannerView(rapidState: rapidState)
                        .toolbar(.hidden, for: .navigationBar)
                        .tag(0)
                    #endif
                }

                // Page 2: Photo Library Import
                PhotoLibraryImportView()
                    .toolbar(.hidden, for: .navigationBar)
                    .tag(canScan ? 1 : 0)

                // Page 3: Manual Entry
                ManualEntryView()
                    .toolbar(.hidden, for: .navigationBar)
                    .tag(canScan ? 2 : 1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Top overlay (mode selector + page indicator)
            VStack(spacing: 12) {
                HStack {
                    // Close button
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    .padding(.leading)

                    Spacer()

                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                    }

                    Spacer()

                    // Placeholder for symmetry
                    Color.clear
                        .frame(width: 44, height: 44)
                        .padding(.trailing)
                }

                // Mode selector (only show on scanner page)
                if currentPage == 0 && canScan {
                    HStack(spacing: 8) {
                        // Standard mode
                        ModeButton(
                            title: "Standard",
                            icon: "viewfinder",
                            isSelected: rapidState.mode == .standard
                        ) {
                            rapidState.mode = .standard
                        }

                        // Rapid mode
                        ModeButton(
                            title: "Rapid",
                            icon: "bolt.fill",
                            isSelected: rapidState.mode == .rapid
                        ) {
                            rapidState.mode = .rapid
                        }

                        // Batch mode
                        ModeButton(
                            title: "Batch",
                            icon: "square.stack.3d.up.fill",
                            isSelected: rapidState.mode == .batch
                        ) {
                            // Show location picker when entering batch mode
                            showingBatchLocationPicker = true
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .sheet(isPresented: $showingBatchLocationPicker) {
                BatchLocationPickerSheet(
                    selectedLocation: Binding(
                        get: { rapidState.batchLocation },
                        set: { newLocation in
                            rapidState.batchLocation = newLocation
                            if newLocation != nil {
                                rapidState.mode = .batch
                            }
                        }
                    )
                )
            }
        }
    }
}

// MARK: - Mode Button

struct ModeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.black.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddCardSwipeableView(canScan: true)
}
