import Foundation

/// Shared brand name normalization and domain resolution for icon lookup.
enum BrandDomainResolver {
    /// Special mappings for known membership and retail brands.
    static let domainMappings: [String: String] = [
        "costco": "costco.com",
        "costco wholesale": "costco.com",
        "sam's club": "samsclub.com",
        "sams club": "samsclub.com",
        "bj's": "bjs.com",
        "bj's wholesale club": "bjs.com",
        "bj's wholesale": "bjs.com",
        "bjs": "bjs.com",
        "whole foods": "wholefoodsmarket.com",
        "whole foods market": "wholefoodsmarket.com",
        "trader joe's": "traderjoes.com",
        "trader joes": "traderjoes.com",
        "kohl's": "kohls.com",
        "kohls": "kohls.com",
        "macy's": "macys.com",
        "macys": "macys.com",
        "target": "target.com",
        "walmart": "walmart.com",
        "cvs": "cvs.com",
        "cvs pharmacy": "cvs.com",
        "walgreens": "walgreens.com",
        "la fitness": "lafitness.com",
        "24 hour fitness": "24hourfitness.com",
        "planet fitness": "planetfitness.com",
        "anytime fitness": "anytimefitness.com",
        "gold's gym": "goldsgym.com",
        "golds gym": "goldsgym.com",
        "starbucks": "starbucks.com",
        "dunkin": "dunkindonuts.com",
        "dunkin'": "dunkindonuts.com",
        "dunkin donuts": "dunkindonuts.com",
        "kroger": "kroger.com",
        "safeway": "safeway.com",
        "albertsons": "albertsons.com",
        "publix": "publix.com",
        "best buy": "bestbuy.com",
        "home depot": "homedepot.com",
        "lowe's": "lowes.com",
        "lowes": "lowes.com",
        "amc": "amctheatres.com",
        "amc theatres": "amctheatres.com",
        "regal": "regmovies.com",
        "regal cinemas": "regmovies.com",
        "cinemark": "cinemark.com",
        "panera": "panerabread.com",
        "panera bread": "panerabread.com",
        "chipotle": "chipotle.com",
        "h-e-b": "heb.com",
        "heb": "heb.com",
        "wegmans": "wegmans.com",
        "meijer": "meijer.com",
        "rei": "rei.com",
        "dick's sporting goods": "dickssportinggoods.com",
        "petsmart": "petsmart.com",
        "petco": "petco.com",
        "mcdonald's": "mcdonalds.com",
        "chick-fil-a": "chick-fil-a.com",
        "subway": "subway.com",
        "shell": "shell.com",
        "chevron": "chevron.com",
        "7-eleven": "7-eleven.com",
        "equinox": "equinox.com",
        "ymca": "ymca.org",
        "crunch fitness": "crunch.com",
        "crunch": "crunch.com",
        "lifetime fitness": "lifetime.life",
        "orangetheory fitness": "orangetheory.com",
        "blink fitness": "blinkfitness.com",
        "ufc gym": "ufcgym.com",
        "food lion": "foodlion.com",
        "hy-vee": "hy-vee.com",
        "shoprite": "shoprite.com",
        "rite aid": "riteaid.com",
        "staples": "staples.com",
        "barnes & noble": "barnesandnoble.com",
        "gamestop": "gamestop.com",
        "taco bell": "tacobell.com",
        "wendy's": "wendys.com",
        "burger king": "bk.com",
        "bp": "bp.com",
        "exxonmobil": "exxon.com",
        "speedway": "speedway.com",
        "circle k": "circlek.com",
        "alamo drafthouse": "drafthouse.com"
    ]

    static func normalizeBrandName(_ name: String) -> String {
        var normalized = name.lowercased()
        let suffixPattern = #"\s+(card|membership|rewards?|club|plus|prime|pass|member|loyalty|account|program)\s*$"#
        normalized = normalized.replacingOccurrences(
            of: suffixPattern,
            with: "",
            options: .regularExpression
        )
        return normalized
            .replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    static func normalizeBrandAlias(_ name: String) -> String {
        var normalized = name.lowercased()
        let suffixPattern = #"\s+(card|membership|rewards?|club|plus|prime|pass|member|loyalty|account|program)\s*$"#
        normalized = normalized.replacingOccurrences(
            of: suffixPattern,
            with: "",
            options: .regularExpression
        )
        return normalized.trimmingCharacters(in: .whitespaces)
    }

    static func determineDomain(for brandName: String) -> String {
        let alias = normalizeBrandAlias(brandName)
        if let mapped = domainMappings[alias] {
            return mapped
        }

        let normalized = normalizeBrandName(brandName)
        for (key, domain) in domainMappings {
            if normalizeBrandName(key) == normalized {
                return domain
            }
        }

        let domain = alias
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "-", with: "")

        return "\(domain).com"
    }

    static func hostFromWebsite(_ website: String?) -> String? {
        guard let website, !website.isEmpty else { return nil }
        let urlString = website.hasPrefix("http") ? website : "https://\(website)"
        guard let url = URL(string: urlString), let host = url.host else { return nil }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}
