import ActivityKit
import WidgetKit
import SwiftUI

@main
struct CardOnCueWidgets: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CardLiveActivityAttributes.self) { context in
            CardLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.cardName)
                            .font(.headline)
                        Text(context.attributes.barcodeType.uppercased())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    BrightnessControl(brightness: context.state.brightness)
                }

                DynamicIslandExpandedRegion(.center) {
                    BarcodeImageView(
                        payload: context.attributes.payload,
                        barcodeType: context.attributes.barcodeType,
                        brightness: context.state.brightness
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Updated: \(context.state.lastUpdate, style: .relative)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            } compactLeading: {
                Image(systemName: barcodeIcon(for: context.attributes.barcodeType))
                    .font(.system(size: 16))
            } compactTrailing: {
                Text(context.attributes.cardName)
                    .font(.caption2)
                    .lineLimit(1)
            } minimal: {
                Image(systemName: barcodeIcon(for: context.attributes.barcodeType))
            }
        }
    }

    private func barcodeIcon(for type: String) -> String {
        switch type.lowercased() {
        case "qr":
            return "qrcode"
        case "pdf417":
            return "doc.text"
        case "aztec":
            return "square.grid.2x2"
        default:
            return "barcode"
        }
    }
}

struct CardLiveActivityView: View {
    let context: ActivityViewContext<CardLiveActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // Location badge (if triggered by location)
                    if let locationName = context.state.locationName {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text(locationName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 2)
                    }

                    Text(context.attributes.cardName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(context.attributes.barcodeType.uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                BrightnessControl(brightness: context.state.brightness)
            }

            BarcodeImageView(
                payload: context.attributes.payload,
                barcodeType: context.attributes.barcodeType,
                brightness: context.state.brightness
            )
            .frame(height: 120)
            .cornerRadius(8)

            HStack {
                // Show card count if multiple available
                if context.state.availableCardsCount > 1 {
                    Label("\(context.state.availableCardsCount) cards available", systemImage: "square.stack.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                Spacer()
                Text("Updated: \(context.state.lastUpdate, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .activityBackgroundTint(.clear)
    }
}

struct BarcodeImageView: View {
    let payload: String
    let barcodeType: String
    let brightness: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(Color.white)

                if let image = generateBarcodeImage(size: geometry.size) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                        .brightness(brightness - 1.0)
                } else {
                    Text("Unable to generate barcode")
                        .foregroundColor(.gray)
                }
            }
        }
    }

    private func generateBarcodeImage(size: CGSize) -> UIImage? {
        let renderer = BarcodeRenderer()
        let barcodeTypeEnum = mapBarcodeType(barcodeType)

        do {
            return try renderer.render(
                payload: payload,
                type: barcodeTypeEnum,
                size: size
            )
        } catch {
            print("Error generating barcode: \(error)")
            return nil
        }
    }

    private func mapBarcodeType(_ type: String) -> BarcodeType {
        switch type.lowercased() {
        case "qr":
            return .qr
        case "code128":
            return .code128
        case "pdf417":
            return .pdf417
        case "aztec":
            return .aztec
        case "ean13":
            return .ean13
        case "upc_a":
            return .upcA
        case "code39":
            return .code39
        case "itf":
            return .itf
        default:
            return .qr
        }
    }
}

struct BrightnessControl: View {
    let brightness: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 12))
                .foregroundColor(.yellow)
            Text("\(Int(brightness * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}
