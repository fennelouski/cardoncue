import SwiftUI

struct AddCardSwipeableView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage: Int
    @State private var rapidState = RapidScanningState()
    @State private var showingBatchLocationPicker = false

    var canScan: Bool

    init(canScan: Bool) {
        self.canScan = canScan
        let savedTab = UserDefaults.standard.integer(forKey: AddCardFlowMetrics.lastTabUserDefaultsKey)
        let maxTab = canScan ? 2 : 1
        let clampedTab = min(max(savedTab, 0), maxTab)
        _currentPage = State(initialValue: clampedTab)
    }

    private var photosPageIndex: Int {
        canScan ? 1 : 0
    }

    private var manualPageIndex: Int {
        canScan ? 2 : 1
    }

    private var isScanPage: Bool {
        canScan && currentPage == 0
    }

    private var segments: [AddCardSegment] {
        var items: [AddCardSegment] = []
        if canScan {
            items.append(AddCardSegment(
                title: NSLocalizedString("add_card_tab_camera", comment: "Camera add-card tab"),
                icon: "camera.fill",
                pageIndex: 0
            ))
        }
        items.append(AddCardSegment(
            title: NSLocalizedString("add_card_tab_photos", comment: "Photos add-card tab"),
            icon: "photo.fill",
            pageIndex: photosPageIndex
        ))
        items.append(AddCardSegment(
            title: NSLocalizedString("add_card_tab_manual", comment: "Manual add-card tab"),
            icon: "keyboard.fill",
            pageIndex: manualPageIndex
        ))
        return items
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $currentPage) {
                if canScan {
                    #if !os(visionOS)
                    BarcodeScannerView(rapidState: rapidState)
                        .tag(0)
                    #endif
                }

                PhotoLibraryImportView(isActive: currentPage == photosPageIndex)
                    .tag(photosPageIndex)

                ManualEntryView()
                    .tag(manualPageIndex)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .environment(\.isInAddCardFlow, true)

            addCardFlowHeader
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
        .onChange(of: currentPage) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: AddCardFlowMetrics.lastTabUserDefaultsKey)
        }
    }

    private var addCardFlowHeader: some View {
        VStack(spacing: AddCardFlowMetrics.rowSpacing) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isScanPage ? .white : .secondary)
                        .shadow(color: isScanPage ? .black.opacity(0.3) : .clear, radius: 2, x: 0, y: 1)
                }
                .frame(width: AddCardFlowMetrics.navigationRowHeight, height: AddCardFlowMetrics.navigationRowHeight)

                Spacer()
            }

            addCardSegmentControl

            if isScanPage {
                HStack(spacing: 8) {
                    ModeButton(
                        title: "Standard",
                        icon: "viewfinder",
                        isSelected: rapidState.mode == .standard
                    ) {
                        rapidState.mode = .standard
                    }

                    ModeButton(
                        title: "Rapid",
                        icon: "bolt.fill",
                        isSelected: rapidState.mode == .rapid
                    ) {
                        rapidState.mode = .rapid
                    }

                    ModeButton(
                        title: "Batch",
                        icon: "square.stack.3d.up.fill",
                        isSelected: rapidState.mode == .batch
                    ) {
                        showingBatchLocationPicker = true
                    }
                }
                .frame(height: AddCardFlowMetrics.modeSelectorRowHeight)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .padding(.top, 8)
        .background {
            if isScanPage {
                LinearGradient(
                    colors: [Color.black.opacity(0.75), Color.black.opacity(0.35), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            } else {
                Color.appBackground
                    .ignoresSafeArea(edges: .top)
            }
        }
        .safeAreaPadding(.top)
    }

    private var addCardSegmentControl: some View {
        HStack(spacing: 4) {
            ForEach(segments) { segment in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentPage = segment.pageIndex
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: segment.icon)
                            .font(.caption)
                        Text(segment.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(segmentForegroundColor(isSelected: currentPage == segment.pageIndex))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(segmentBackgroundColor(isSelected: currentPage == segment.pageIndex))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: AddCardFlowMetrics.segmentRowHeight)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isScanPage ? Color.black.opacity(0.35) : Color.appBlue.opacity(0.08))
        )
    }

    private func segmentForegroundColor(isSelected: Bool) -> Color {
        if isScanPage {
            return isSelected ? .white : .white.opacity(0.65)
        }
        return isSelected ? .white : Color.appBlue
    }

    private func segmentBackgroundColor(isSelected: Bool) -> Color {
        if isScanPage {
            return isSelected ? Color.blue : Color.clear
        }
        return isSelected ? Color.appPrimary : Color.clear
    }
}

private struct AddCardSegment: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let pageIndex: Int
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
