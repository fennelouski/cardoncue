//
//  CardCategory.swift
//  CardOnCue
//
//  Single source of truth for the brand/business categories a card can belong
//  to. Drives (1) the auto-assigned SF Symbol in CardIconService, (2) per-card
//  color themes, (3) the small category icons shown in a cell corner, and
//  (4) "Group by category" in the list.
//

import SwiftUI

enum CardCategory: String, CaseIterable, Identifiable {
    // Order matters: it defines match precedence (first match wins for the
    // icon service). This mirrors the original CardIconService branch order.
    case library, fitness, wholesale, market, grocery, retail, coffee,
         restaurant, pharmacy, gas, hotel, cinema, museum, park, card

    var id: String { rawValue }

    var label: String {
        switch self {
        case .library:    return NSLocalizedString("category_library", value: "Library", comment: "Card category")
        case .fitness:    return NSLocalizedString("category_fitness", value: "Fitness", comment: "Card category")
        case .wholesale:  return NSLocalizedString("category_wholesale", value: "Wholesale", comment: "Card category")
        case .market:     return NSLocalizedString("category_market", value: "Market", comment: "Card category")
        case .grocery:    return NSLocalizedString("category_grocery", value: "Grocery", comment: "Card category")
        case .retail:     return NSLocalizedString("category_retail", value: "Retail", comment: "Card category")
        case .coffee:     return NSLocalizedString("category_coffee", value: "Coffee", comment: "Card category")
        case .restaurant: return NSLocalizedString("category_restaurant", value: "Restaurant", comment: "Card category")
        case .pharmacy:   return NSLocalizedString("category_pharmacy", value: "Pharmacy", comment: "Card category")
        case .gas:        return NSLocalizedString("category_gas", value: "Gas", comment: "Card category")
        case .hotel:      return NSLocalizedString("category_hotel", value: "Hotel", comment: "Card category")
        case .cinema:     return NSLocalizedString("category_cinema", value: "Cinema", comment: "Card category")
        case .museum:     return NSLocalizedString("category_museum", value: "Museum", comment: "Card category")
        case .park:       return NSLocalizedString("category_park", value: "Park", comment: "Card category")
        case .card:       return NSLocalizedString("category_card", value: "Card", comment: "Card category")
        }
    }

    var sfSymbol: String {
        switch self {
        case .library:    return "book.closed.fill"
        case .fitness:    return "figure.run"
        case .wholesale:  return "cart.fill"
        case .market:     return "basket.fill"
        case .grocery:    return "cart.fill"
        case .retail:     return "bag.fill"
        case .coffee:     return "cup.and.saucer.fill"
        case .restaurant: return "fork.knife"
        case .pharmacy:   return "cross.case.fill"
        case .gas:        return "fuelpump.fill"
        case .hotel:      return "bed.double.fill"
        case .cinema:     return "film.fill"
        case .museum:     return "building.columns.fill"
        case .park:       return "tree.fill"
        case .card:       return "creditcard.fill"
        }
    }

    /// Subtle theme color for the category. System colors adapt to light/dark.
    var tint: Color {
        switch self {
        case .library:    return .indigo
        case .fitness:    return .green
        case .wholesale:  return .orange
        case .market:     return .mint
        case .grocery:    return .teal
        case .retail:     return .pink
        case .coffee:     return .brown
        case .restaurant: return .red
        case .pharmacy:   return Color(.systemRed)
        case .gas:        return .blue
        case .hotel:      return .purple
        case .cinema:     return Color(.systemPurple)
        case .museum:     return Color(.systemBrown)
        case .park:       return Color(.systemGreen)
        case .card:       return .appBlue
        }
    }

    /// Keywords that map text to this category. `.card` is the catch-all and
    /// matches nothing directly (used only as an explicit fallback).
    private var keywords: [String] {
        switch self {
        case .library:    return ["library"]
        case .fitness:    return ["gym", "fitness", "athletic", "sport"]
        case .wholesale:  return ["costco", "wholesale"]
        case .market:     return ["whole foods", "market"]
        case .grocery:    return ["grocery", "supermarket"]
        case .retail:     return ["kohl", "retail", "department"]
        case .coffee:     return ["coffee", "cafe", "starbucks"]
        case .restaurant: return ["restaurant", "dining"]
        case .pharmacy:   return ["pharmacy", "drug", "cvs", "walgreens"]
        case .gas:        return ["gas", "fuel", "shell", "bp"]
        case .hotel:      return ["hotel", "resort"]
        case .cinema:     return ["cinema", "theater", "movie"]
        case .museum:     return ["museum", "gallery"]
        case .park:       return ["park", "recreation"]
        case .card:       return []
        }
    }

    /// All categories whose keywords appear in `text`, in precedence order.
    static func matches(in text: String) -> [CardCategory] {
        let lower = text.lowercased()
        return allCases.filter { category in
            category.keywords.contains { lower.contains($0) }
        }
    }

    /// Deterministic color for a string, used when a card matches no category.
    /// Uses an FNV-1a fold (NOT String.hashValue, which is per-process
    /// randomized and would change the color on every launch).
    static func stableTint(for key: String) -> Color {
        var hash: UInt64 = 1469598103934665603 // FNV offset basis
        for byte in key.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1099511628211 // FNV prime
        }
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.45, brightness: 0.72)
    }
}

// MARK: - CardModel categorization

extension CardModel {
    /// Every category this card fits, derived from its name + location.
    var categories: [CardCategory] {
        let text = [name, locationName ?? ""].joined(separator: " ")
        return CardCategory.matches(in: text)
    }

    /// Color theme for the card: its first category's tint, else a stable hue.
    var themeTint: Color {
        categories.first?.tint ?? CardCategory.stableTint(for: groupKey)
    }
}
