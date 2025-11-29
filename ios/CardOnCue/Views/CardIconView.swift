import SwiftUI

struct CardIconView: View {
    let card: Card
    var size: CGFloat = 48

    @State private var iconImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let iconImage = iconImage {
                Image(uiImage: iconImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size / 6))
            } else if isLoading {
                RoundedRectangle(cornerRadius: size / 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            } else {
                placeholderIcon
            }
        }
        .task {
            await loadIcon()
        }
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: size / 6)
            .fill(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "creditcard.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(.white.opacity(0.8))
            )
    }

    private func loadIcon() async {
        defer { isLoading = false }

        guard let iconUrlString = card.iconUrl,
              let url = URL(string: iconUrlString) else {
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            if let image = UIImage(data: data) {
                await MainActor.run {
                    iconImage = image
                }
            }
        } catch {
            print("Failed to load icon: \(error)")
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CardIconView(
            card: Card(
                id: "1",
                userId: "user1",
                name: "Costco",
                barcodeType: .qr,
                payload: "12345",
                tags: [],
                networkIds: [],
                oneTime: false,
                usedAt: nil,
                metadata: [:],
                createdAt: Date(),
                updatedAt: Date(),
                defaultIconUrl: "https://logo.clearbit.com/costco.com",
                customIconUrl: nil
            ),
            size: 64
        )

        CardIconView(
            card: Card(
                id: "2",
                userId: "user1",
                name: "Amazon",
                barcodeType: .qr,
                payload: "67890",
                tags: [],
                networkIds: [],
                oneTime: false,
                usedAt: nil,
                metadata: [:],
                createdAt: Date(),
                updatedAt: Date(),
                defaultIconUrl: nil,
                customIconUrl: nil
            ),
            size: 48
        )
    }
    .padding()
}
