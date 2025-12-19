import SwiftUI
import PhotosUI

struct IconSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: CardIcon?
    
    let card: CardModel
    let autoIcon: CardIcon? // The automatically assigned icon
    
    @State private var selectedTab: IconTab = .automatic
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingDrawingPad = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    
    enum IconTab {
        case automatic
        case scannedImage
        case photoLibrary
        case camera
        case sfSymbol
        case emoji
        case text
        case drawing
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        TabButton(title: "Auto", icon: "sparkles", isSelected: selectedTab == .automatic) {
                            selectedTab = .automatic
                        }
                        
                        TabButton(title: "Scanned", icon: "doc.text.viewfinder", isSelected: selectedTab == .scannedImage) {
                            selectedTab = .scannedImage
                        }
                        
                        TabButton(title: "Library", icon: "photo.on.rectangle", isSelected: selectedTab == .photoLibrary) {
                            selectedTab = .photoLibrary
                        }
                        
                        TabButton(title: "Camera", icon: "camera.fill", isSelected: selectedTab == .camera) {
                            selectedTab = .camera
                        }
                        
                        TabButton(title: "Symbol", icon: "square.grid.2x2", isSelected: selectedTab == .sfSymbol) {
                            selectedTab = .sfSymbol
                        }
                        
                        TabButton(title: "Emoji", icon: "face.smiling", isSelected: selectedTab == .emoji) {
                            selectedTab = .emoji
                        }
                        
                        TabButton(title: "Text", icon: "textformat", isSelected: selectedTab == .text) {
                            selectedTab = .text
                        }
                        
                        TabButton(title: "Draw", icon: "pencil.and.outline", isSelected: selectedTab == .drawing) {
                            selectedTab = .drawing
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color.gray.opacity(0.1))
                
                // Content for selected tab
                ScrollView {
                    Group {
                        switch selectedTab {
                        case .automatic:
                            AutomaticIconView(icon: autoIcon) { icon in
                                selectIcon(icon)
                            }
                        case .scannedImage:
                            ScannedImageIconView(card: card) { icon in
                                selectIcon(icon)
                            }
                        case .photoLibrary:
                            PhotoLibraryIconView(card: card) { icon in
                                selectIcon(icon)
                            }
                        case .camera:
                            CameraIconView(card: card) { icon in
                                selectIcon(icon)
                            }
                        case .sfSymbol:
                            SFSymbolIconView(selectedIcon: $selectedIcon) { icon in
                                selectIcon(icon)
                            }
                        case .emoji:
                            EmojiIconView { icon in
                                selectIcon(icon)
                            }
                        case .text:
                            TextIconView(card: card) { icon in
                                selectIcon(icon)
                            }
                        case .drawing:
                            DrawingIconView(card: card) { icon in
                                selectIcon(icon)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Select Icon")
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
    
    private func selectIcon(_ icon: CardIcon) {
        selectedIcon = icon
        dismiss()
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .white : .appBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.appBlue : Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
    }
}

// MARK: - Automatic Icon View

struct AutomaticIconView: View {
    let icon: CardIcon?
    let onSelect: (CardIcon) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            if let icon = icon {
                VStack(spacing: 16) {
                    Text("Automatically Selected")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    CardIconDisplay(icon: icon, size: 80)
                    
                    Text("This icon was automatically chosen based on your card name.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        onSelect(icon)
                    }) {
                        Text("Use This Icon")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appBlue)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else {
                Text("No automatic icon available")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Scanned Image Icon View

struct ScannedImageIconView: View {
    let card: CardModel
    let onSelect: (CardIcon) -> Void
    
    @State private var cardImage: UIImage?
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Use Card Image")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let cardImage = cardImage {
                VStack(spacing: 12) {
                    Image(uiImage: cardImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                    
                    Button(action: {
                        if let iconURL = CardImageStorageService.shared.getIconImageURL(cardId: card.id),
                           CardImageStorageService.shared.loadImage(from: iconURL) != nil {
                            // Use existing icon
                            let icon = CardIcon.image(iconURL.path)
                            onSelect(icon)
                        } else {
                            // Save card image as icon
                            Task {
                                await saveCardImageAsIcon(cardImage)
                            }
                        }
                    }) {
                        Text("Use This Image as Icon")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appBlue)
                            .cornerRadius(12)
                    }
                }
            } else {
                Text("No card image available")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .onAppear {
            loadCardImage()
        }
    }
    
    private func loadCardImage() {
        if let displayURL = card.displayImageURL,
           let url = URL(string: displayURL),
           let image = CardImageStorageService.shared.loadImage(from: url) {
            cardImage = image
        }
    }
    
    private func saveCardImageAsIcon(_ image: UIImage) async {
        do {
            let iconURL = try CardImageStorageService.shared.saveIconImage(image, cardId: card.id)
            let icon = CardIcon.image(iconURL.path)
            await MainActor.run {
                onSelect(icon)
            }
        } catch {
            print("Failed to save icon image: \(error)")
        }
    }
}

// MARK: - Photo Library Icon View

struct PhotoLibraryIconView: View {
    let card: CardModel
    let onSelect: (CardIcon) -> Void
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Choose from Photo Library")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Select Photo")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appBlue)
                .cornerRadius(12)
            }
            
            if let selectedImage = selectedImage {
                VStack(spacing: 12) {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                    
                    Button(action: {
                        Task {
                            await saveImageAsIcon(selectedImage)
                        }
                    }) {
                        Text("Use This Image")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appBlue)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = image
                    }
                }
            }
        }
    }
    
    private func saveImageAsIcon(_ image: UIImage) async {
        do {
            let iconURL = try CardImageStorageService.shared.saveIconImage(image, cardId: card.id)
            let icon = CardIcon.image(iconURL.path)
            await MainActor.run {
                onSelect(icon)
            }
        } catch {
            print("Failed to save icon image: \(error)")
        }
    }
}

// MARK: - Camera Icon View

struct CameraIconView: View {
    let card: CardModel
    let onSelect: (CardIcon) -> Void
    
    @State private var showingImagePicker = false
    @State private var capturedImage: UIImage?
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Take Photo")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: {
                showingImagePicker = true
            }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Open Camera")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appBlue)
                .cornerRadius(12)
            }
            
            if let capturedImage = capturedImage {
                VStack(spacing: 12) {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                    
                    Button(action: {
                        Task {
                            await saveImageAsIcon(capturedImage)
                        }
                    }) {
                        Text("Use This Photo")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appBlue)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(sourceType: .camera, selectedImage: $capturedImage)
        }
    }
    
    private func saveImageAsIcon(_ image: UIImage) async {
        do {
            let iconURL = try CardImageStorageService.shared.saveIconImage(image, cardId: card.id)
            let icon = CardIcon.image(iconURL.path)
            await MainActor.run {
                onSelect(icon)
            }
        } catch {
            print("Failed to save icon image: \(error)")
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - SF Symbol Icon View (with color picker)

struct SFSymbolIconView: View {
    @Binding var selectedIcon: CardIcon?
    let onSelect: (CardIcon) -> Void
    
    @State private var searchText: String = ""
    @State private var selectedCategory: IconCategory? = nil
    @State private var selectedSymbol: String = ""
    @State private var selectedColor: Color = .appBlue
    @State private var selectedBackgroundColor: Color? = nil
    @State private var showingColorPicker = false
    
    private let iconCategories: [IconCategory] = [
        IconCategory(name: "General", icons: ["creditcard.fill", "qrcode", "barcode", "wallet.pass.fill"]),
        IconCategory(name: "Library", icons: ["book.closed.fill", "book.fill", "books.vertical.fill", "text.book.closed.fill"]),
        IconCategory(name: "Fitness", icons: ["figure.run", "figure.walk", "dumbbell.fill", "sportscourt.fill"]),
        IconCategory(name: "Shopping", icons: ["cart.fill", "basket.fill", "bag.fill", "bag.circle.fill"]),
        IconCategory(name: "Food & Drink", icons: ["cup.and.saucer.fill", "fork.knife", "takeoutbag.and.cup.and.straw.fill"]),
        IconCategory(name: "Healthcare", icons: ["cross.case.fill", "heart.fill", "cross.fill", "pills.fill"]),
        IconCategory(name: "Travel", icons: ["fuelpump.fill", "airplane", "car.fill", "bed.double.fill"]),
        IconCategory(name: "Entertainment", icons: ["film.fill", "tv.fill", "music.note", "gamecontroller.fill"]),
        IconCategory(name: "Education", icons: ["building.columns.fill", "graduationcap.fill", "studentdesk"]),
        IconCategory(name: "Recreation", icons: ["tree.fill", "leaf.fill", "figure.hiking"])
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Preview
            if !selectedSymbol.isEmpty {
                VStack(spacing: 12) {
                    CardIconDisplay(
                        icon: CardIcon.sfSymbol(selectedSymbol, color: selectedColor, backgroundColor: selectedBackgroundColor),
                        size: 80
                    )
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            showingColorPicker.toggle()
                        }) {
                            HStack {
                                Circle()
                                    .fill(selectedColor)
                                    .frame(width: 24, height: 24)
                                Text("Color")
                            }
                            .font(.subheadline)
                            .foregroundColor(.appBlue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Button(action: {
                            selectedBackgroundColor = selectedBackgroundColor == nil ? Color.gray.opacity(0.2) : nil
                        }) {
                            HStack {
                                if let bgColor = selectedBackgroundColor {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(bgColor)
                                        .frame(width: 24, height: 24)
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.gray, lineWidth: 2)
                                        .frame(width: 24, height: 24)
                                }
                                Text("Background")
                            }
                            .font(.subheadline)
                            .foregroundColor(.appBlue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    Button(action: {
                        let icon = CardIcon.sfSymbol(selectedSymbol, color: selectedColor, backgroundColor: selectedBackgroundColor)
                        onSelect(icon)
                    }) {
                        Text("Use This Icon")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appBlue)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search symbols...", text: $searchText)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(iconCategories, id: \.name) { category in
                        CategoryChip(title: category.name, isSelected: selectedCategory?.name == category.name) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Icon grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 16)], spacing: 16) {
                ForEach(filteredIcons, id: \.self) { iconName in
                    IconButton(
                        iconName: iconName,
                        isSelected: selectedSymbol == iconName,
                        action: {
                            selectedSymbol = iconName
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerView(selectedColor: $selectedColor, selectedBackgroundColor: $selectedBackgroundColor)
        }
    }
    
    private var filteredIcons: [String] {
        var icons: [String] = []
        let categoriesToShow = selectedCategory != nil ? [selectedCategory!] : iconCategories
        
        for category in categoriesToShow {
            icons.append(contentsOf: category.icons)
        }
        
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            icons = icons.filter { $0.lowercased().contains(searchLower) }
        }
        
        return Array(Set(icons)).sorted()
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .appBlue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.appBlue : Color.gray.opacity(0.1))
                .cornerRadius(20)
        }
    }
}

struct IconButton: View {
    let iconName: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 32))
                .foregroundColor(isSelected ? .white : .appBlue)
                .frame(width: 60, height: 60)
                .background(isSelected ? Color.appBlue : Color.gray.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.appBlue : Color.clear, lineWidth: 2)
                )
        }
    }
}

// MARK: - Emoji Icon View

struct EmojiIconView: View {
    let onSelect: (CardIcon) -> Void
    
    @State private var searchText: String = ""
    @State private var selectedEmoji: String = ""
    
    private let emojiCategories: [(String, [String])] = [
        ("Recent", []),
        ("Smileys", ["😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙"]),
        ("Objects", ["💳", "🎫", "📱", "💻", "⌚", "📷", "🎮", "🎯", "🏆", "🏅", "🎖️", "🏵️", "🎗️", "🎟️", "🎪", "🎭", "🎨", "🎬", "🎤", "🎧"]),
        ("Food", ["🍎", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥬", "🥒"]),
        ("Travel", ["🚗", "🚕", "🚙", "🚌", "🚎", "🏎️", "🚓", "🚑", "🚒", "🚐", "🚚", "🚛", "🚜", "🛴", "🚲", "🛵", "🏍️", "🛺", "🚨", "🚔"]),
        ("Symbols", ["⭐", "🌟", "💫", "✨", "💥", "💢", "💯", "💢", "🔥", "💧", "💦", "💨", "⚡", "☄️", "🌙", "⭐", "🌟", "💫", "✨", "💥"])
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            if !selectedEmoji.isEmpty {
                VStack(spacing: 12) {
                    Text(selectedEmoji)
                        .font(.system(size: 80))
                    
                    Button(action: {
                        let icon = CardIcon.emoji(selectedEmoji)
                        onSelect(icon)
                    }) {
                        Text("Use This Emoji")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appBlue)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search emojis...", text: $searchText)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Emoji grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 50), spacing: 12)], spacing: 12) {
                    ForEach(filteredEmojis, id: \.self) { emoji in
                        Button(action: {
                            selectedEmoji = emoji
                        }) {
                            Text(emoji)
                                .font(.system(size: 40))
                                .frame(width: 50, height: 50)
                                .background(selectedEmoji == emoji ? Color.appBlue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
    
    private var filteredEmojis: [String] {
        let allEmojis = emojiCategories.flatMap { $0.1 }
        if searchText.isEmpty {
            return allEmojis
        }
        // Simple filter - in a real app, you'd want better emoji search
        return allEmojis.filter { $0.contains(searchText) || searchText.isEmpty }
    }
}

// MARK: - Text Icon View

struct TextIconView: View {
    let card: CardModel
    let onSelect: (CardIcon) -> Void
    
    @State private var textInput: String = ""
    @State private var textColor: Color = .appBlue
    @State private var backgroundColor: Color = .white
    @State private var fontSize: CGFloat = 40
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Create Text Icon")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Preview
            if !textInput.isEmpty {
                VStack(spacing: 12) {
                    Text(textInput.prefix(2).uppercased())
                        .font(.system(size: fontSize, weight: .bold))
                        .foregroundColor(textColor)
                        .frame(width: 80, height: 80)
                        .background(backgroundColor)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Text input
            TextField("Enter text (1-2 characters)", text: $textInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.allCharacters)
                .onChange(of: textInput) { _, newValue in
                    // Limit to 2 characters
                    if newValue.count > 2 {
                        textInput = String(newValue.prefix(2))
                    }
                }
            
            // Color pickers
            VStack(spacing: 12) {
                HStack {
                    Text("Text Color")
                    Spacer()
                    ColorPicker("", selection: $textColor)
                }
                
                HStack {
                    Text("Background")
                    Spacer()
                    ColorPicker("", selection: $backgroundColor)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Font size
            VStack(alignment: .leading, spacing: 8) {
                Text("Font Size: \(Int(fontSize))")
                Slider(value: $fontSize, in: 20...60)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Button(action: {
                Task {
                    await createTextIcon()
                }
            }) {
                Text("Create Icon")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(textInput.isEmpty ? Color.gray : Color.appBlue)
                    .cornerRadius(12)
            }
            .disabled(textInput.isEmpty)
        }
    }
    
    private func createTextIcon() async {
        // Render text as image
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let bgColor = UIColor(backgroundColor)
        let txtColor = UIColor(textColor)
        let image = renderer.image { context in
            bgColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let text = textInput.prefix(2).uppercased()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: txtColor
            ]
            let attributedString = NSAttributedString(string: String(text), attributes: attributes)
            let textSize = attributedString.size()
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            attributedString.draw(in: textRect)
        }
        
        do {
            let iconURL = try CardImageStorageService.shared.saveIconImage(image, cardId: card.id)
            let icon = CardIcon.image(iconURL.path) // Save as image type since it's rendered
            await MainActor.run {
                onSelect(icon)
            }
        } catch {
            print("Failed to save text icon: \(error)")
        }
    }
}

// MARK: - Drawing Icon View

struct DrawingIconView: View {
    let card: CardModel
    let onSelect: (CardIcon) -> Void
    
    @State private var showingDrawingPad = false
    @State private var hasExistingDrawing = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Draw Your Icon")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Check if drawing exists
            if hasExistingDrawing {
                VStack(spacing: 12) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 40))
                        .foregroundColor(.appBlue)
                    
                    Text("You have a saved drawing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showingDrawingPad = true
                    }) {
                        HStack {
                            Image(systemName: "pencil.and.outline")
                            Text("Edit Drawing")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appBlue)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        // Delete existing drawing and create new
                        CardImageStorageService.shared.deleteDrawingData(for: card.id)
                        CardImageStorageService.shared.deleteIconImage(for: card.id)
                        hasExistingDrawing = false
                        showingDrawingPad = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Start New Drawing")
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            } else {
                Text("Create a custom icon by drawing")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    showingDrawingPad = true
                }) {
                    HStack {
                        Image(systemName: "pencil.and.outline")
                        Text("Open Drawing Pad")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appBlue)
                    .cornerRadius(12)
                }
            }
        }
        .onAppear {
            checkForExistingDrawing()
        }
        .sheet(isPresented: $showingDrawingPad) {
            DrawingPadView(card: card) { icon in
                onSelect(icon)
                showingDrawingPad = false
                checkForExistingDrawing()
            }
        }
    }
    
    private func checkForExistingDrawing() {
        hasExistingDrawing = CardImageStorageService.shared.getDrawingDataURL(cardId: card.id) != nil
    }
}

// MARK: - Color Picker View

struct ColorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedColor: Color
    @Binding var selectedBackgroundColor: Color?
    
    let presetColors: [Color] = [
        .appBlue, .appGreen, .red, .orange, .yellow,
        .purple, .pink, .cyan, .mint, .indigo
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Primary color
                VStack(alignment: .leading, spacing: 12) {
                    Text("Icon Color")
                        .font(.headline)
                    
                    ColorPicker("", selection: $selectedColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(presetColors, id: \.description) { color in
                                Button(action: {
                                    selectedColor = color
                                }) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                        )
                                }
                            }
                        }
                    }
                }
                
                // Background color
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Background Color")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            selectedBackgroundColor = nil
                        }) {
                            Text("None")
                                .font(.subheadline)
                                .foregroundColor(.appBlue)
                        }
                    }
                    
                    if selectedBackgroundColor != nil {
                        ColorPicker("", selection: Binding(
                            get: { selectedBackgroundColor ?? .white },
                            set: { selectedBackgroundColor = $0 }
                        ))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Choose Colors")
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

// MARK: - Icon Display Component

struct CardIconDisplay: View {
    let icon: CardIcon?
    let size: CGFloat
    
    @ViewBuilder
    var body: some View {
        if let icon = icon {
            switch icon.type {
            case .automatic, .sfSymbol:
                Image(systemName: icon.value.isEmpty ? "creditcard.fill" : icon.value)
                    .font(.system(size: size * 0.6))
                    .foregroundColor(icon.colorHex != nil ? Color.fromHex(icon.colorHex!) : .appBlue)
                    .frame(width: size, height: size)
                    .background(
                        icon.backgroundColorHex != nil
                            ? Color.fromHex(icon.backgroundColorHex!)
                            : Color.gray.opacity(0.1)
                    )
                    .cornerRadius(size * 0.2)
            
            case .image, .drawing:
                iconImageView(icon: icon)
            
            case .emoji:
                Text(icon.value)
                    .font(.system(size: size * 0.7))
                    .frame(width: size, height: size)
            
            case .text:
                Text(icon.value.prefix(2).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.appBlue)
                    .frame(width: size, height: size)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(size * 0.2)
            }
        } else {
            Image(systemName: "creditcard.fill")
                .font(.system(size: size * 0.6))
                .foregroundColor(.gray)
        }
    }
    
    @ViewBuilder
    private func iconImageView(icon: CardIcon) -> some View {
        if let imageURL = iconImageURL(icon: icon),
           let image = CardImageStorageService.shared.loadImage(from: imageURL) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .cornerRadius(size * 0.2)
        } else {
            Image(systemName: "photo")
                .font(.system(size: size * 0.6))
                .foregroundColor(.gray)
        }
    }
    
    private func iconImageURL(icon: CardIcon) -> URL? {
        if icon.value.hasPrefix("/") || icon.value.hasPrefix("file://") {
            // File path
            return URL(fileURLWithPath: icon.value.replacingOccurrences(of: "file://", with: ""))
        } else if let url = URL(string: icon.value) {
            // URL string
            return url
        } else {
            return nil
        }
    }
}

struct IconCategory {
    let name: String
    let icons: [String]
}

#Preview {
    IconSelectionView(
        selectedIcon: .constant(nil),
        card: CardModel(userId: "test", name: "Test", barcodeType: .qr, payloadEncrypted: Data()),
        autoIcon: CardIcon.sfSymbol("creditcard.fill")
    )
}
