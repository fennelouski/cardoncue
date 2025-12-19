import Foundation

/// Service for detecting and segmenting OCR text into structured fields
class OCRSegmentDetector {
    static let shared = OCRSegmentDetector()

    private init() {}

    /// Detect and segment text from OCR result
    func detectSegments(from ocrResult: VisionOCRService.OCRResult, parsedData: ParsedCardData?) -> [OCRField] {
        let textLines = ocrResult.allText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var segments: [OCRField] = []
        var usedLineIndices = Set<Int>()

        // 1. Person Name (use CardDataParser result if available)
        if let personName = parsedData?.personName, !personName.isEmpty {
            segments.append(OCRField(
                type: .personName,
                value: personName,
                confidence: parsedData?.personNameConfidence
            ))
            // Find and mark line as used
            if let lineIndex = textLines.firstIndex(where: { $0.contains(personName) }) {
                usedLineIndices.insert(lineIndex)
            }
        }

        // 2. Member ID (from OCR result or detect)
        if let memberId = ocrResult.memberId, !memberId.isEmpty {
            segments.append(OCRField(
                type: .memberId,
                value: memberId,
                confidence: ocrResult.confidence
            ))
        } else {
            // Detect ID patterns
            for (index, line) in textLines.enumerated() where !usedLineIndices.contains(index) {
                if let id = detectMemberId(in: line) {
                    segments.append(OCRField(
                        type: .memberId,
                        value: id,
                        sourceLineIndex: index
                    ))
                    usedLineIndices.insert(index)
                    break
                }
            }
        }

        // 3. Email addresses
        for (index, line) in textLines.enumerated() where !usedLineIndices.contains(index) {
            if let email = detectEmail(in: line) {
                segments.append(OCRField(
                    type: .email,
                    value: email,
                    sourceLineIndex: index
                ))
                usedLineIndices.insert(index)
            }
        }

        // 4. Phone numbers
        for (index, line) in textLines.enumerated() where !usedLineIndices.contains(index) {
            if let phone = detectPhoneNumber(in: line) {
                segments.append(OCRField(
                    type: .phoneNumber,
                    value: phone,
                    sourceLineIndex: index
                ))
                usedLineIndices.insert(index)
            }
        }

        // 5. PIN (detect before website to avoid conflicts)
        for (index, line) in textLines.enumerated() where !usedLineIndices.contains(index) {
            if let pin = detectPIN(in: line) {
                segments.append(OCRField(
                    type: .pin,
                    value: pin,
                    sourceLineIndex: index
                ))
                usedLineIndices.insert(index)
            }
        }

        // 6. Website URLs
        for (index, line) in textLines.enumerated() where !usedLineIndices.contains(index) {
            if let website = detectWebsite(in: line) {
                segments.append(OCRField(
                    type: .website,
                    value: website,
                    sourceLineIndex: index
                ))
                usedLineIndices.insert(index)
            }
        }

        // 7. Card Type (e.g., "Fun Pass", "Gold Card", "Membership")
        for (index, line) in textLines.enumerated() where !usedLineIndices.contains(index) {
            if let cardType = detectCardType(in: line) {
                segments.append(OCRField(
                    type: .cardType,
                    value: cardType,
                    sourceLineIndex: index
                ))
                usedLineIndices.insert(index)
            }
        }

        // 8. Membership level
        for (index, line) in textLines.enumerated() where !usedLineIndices.contains(index) {
            if let membershipLevel = detectMembershipLevel(in: line) {
                segments.append(OCRField(
                    type: .membershipLevel,
                    value: membershipLevel,
                    sourceLineIndex: index
                ))
                usedLineIndices.insert(index)
            }
        }

        // 9. Season/Year
        for (index, line) in textLines.enumerated() where !usedLineIndices.contains(index) {
            if let season = detectSeason(in: line) {
                segments.append(OCRField(
                    type: .season,
                    value: season,
                    sourceLineIndex: index
                ))
                usedLineIndices.insert(index)
            }
        }

        // 10. Expiration dates
        for (index, line) in textLines.enumerated() where !usedLineIndices.contains(index) {
            if let expDate = detectExpirationDate(in: line) {
                segments.append(OCRField(
                    type: .expirationDate,
                    value: expDate,
                    sourceLineIndex: index
                ))
                usedLineIndices.insert(index)
            }
        }

        // 11. Address (multi-line detection)
        if let addressSegment = detectAddress(from: textLines, usedIndices: usedLineIndices) {
            segments.append(addressSegment.field)
            addressSegment.usedIndices.forEach { usedLineIndices.insert($0) }
        }

        // 12. Remaining lines as "Other"
        for (index, line) in textLines.enumerated() where !usedLineIndices.contains(index) {
            // Skip very short lines, card name, or label-only text
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 2 && trimmed != ocrResult.cardName && !isLabelOnly(trimmed) {
                segments.append(OCRField(
                    type: .other,
                    value: trimmed,
                    sourceLineIndex: index
                ))
            }
        }

        return segments
    }

    // MARK: - Pattern Detection

    private func detectMemberId(in text: String) -> String? {
        // Pattern: Look for "ID:", "Member:", "Number:", etc. followed by alphanumeric
        let patterns = [
            #"(?:ID|Member|Card|Account|Number)\s*[:#]?\s*([A-Z0-9-]{5,})"#,
            #"\b([A-Z0-9]{8,})\b"#, // Standalone long alphanumeric
            #"\b(\d{8,})\b"# // Standalone long numeric (8+ digits)
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                // Try to get capture group first, fallback to full match
                let captureRange = match.range(at: 1)
                let rangeToUse = captureRange.location != NSNotFound ? captureRange : match.range
                guard let range = Range(rangeToUse, in: text) else { continue }
                return String(text[range])
            }
        }
        return nil
    }

    private func detectEmail(in text: String) -> String? {
        let pattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func detectPhoneNumber(in text: String) -> String? {
        // Normalize text: replace common OCR mistakes
        var normalized = text.replacingOccurrences(of: "O", with: "0", options: .literal)

        // Patterns for various phone formats
        let patterns = [
            #"\d{3}\.\d{3}\.\d{4}"#, // 303.335.4849
            #"\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#, // (555) 123-4567, 555-123-4567
            #"\+?1?\s?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#, // +1 (555) 123-4567
            #"\d{10}"# // 3033354849
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
               let range = Range(match.range, in: normalized) {
                var phoneNumber = String(normalized[range])

                // Format consistently as (XXX) XXX-XXXX
                let digitsOnly = phoneNumber.filter { $0.isNumber }
                if digitsOnly.count == 10 {
                    let areaCode = digitsOnly.prefix(3)
                    let prefix = digitsOnly.dropFirst(3).prefix(3)
                    let lineNumber = digitsOnly.suffix(4)
                    phoneNumber = "(\(areaCode)) \(prefix)-\(lineNumber)"
                }

                return phoneNumber
            }
        }
        return nil
    }

    private func detectWebsite(in text: String) -> String? {
        // Support hyphens in domain names
        let pattern = #"(?:https?://)?(?:www\.)?[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]\.[a-zA-Z]{2,}(?:\.[a-zA-Z]{2,})?(?:/[^\s]*)?"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }

        var website = String(text[range])

        // Add https:// if not present
        if !website.hasPrefix("http://") && !website.hasPrefix("https://") {
            website = "https://" + website
        }

        // Validate domain has at least one letter
        let domainPart = website.replacingOccurrences(of: "https://", with: "")
                                .replacingOccurrences(of: "http://", with: "")
                                .components(separatedBy: "/").first ?? ""

        let hasLetters = domainPart.contains(where: { $0.isLetter })
        guard hasLetters else { return nil }

        return website
    }

    private func detectExpirationDate(in text: String) -> String? {
        // Look for "Exp:", "Expires:", "Valid Thru:", etc.
        let keywords = ["exp", "expires", "expiry", "valid", "thru"]
        let lowercased = text.lowercased()

        guard keywords.contains(where: { lowercased.contains($0) }) else {
            return nil
        }

        // Extract date patterns: MM/YY, MM/YYYY, Month Year
        let datePatterns = [
            #"(\d{2}/\d{2,4})"#, // 12/25, 12/2025
            #"(\d{2}-\d{2,4})"#, // 12-25, 12-2025
            #"((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})"# // Jan 2025
        ]

        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }

        return nil
    }

    private func detectAddress(from lines: [String], usedIndices: Set<Int>) -> (field: OCRField, usedIndices: Set<Int>)? {
        // Look for address keywords: street numbers, street types, city/state patterns
        let addressKeywords = ["st", "street", "ave", "avenue", "rd", "road", "blvd", "boulevard", "drive", "dr", "lane", "ln"]

        var addressLines: [(index: Int, text: String)] = []

        for (index, line) in lines.enumerated() where !usedIndices.contains(index) {
            let lowercased = line.lowercased()

            // Check for street address patterns
            let hasStreetNumber = line.range(of: #"^\d+"#, options: .regularExpression) != nil
            let hasStreetKeyword = addressKeywords.contains { lowercased.contains($0) }
            let hasZipCode = line.range(of: #"\b\d{5}(?:-\d{4})?\b"#, options: .regularExpression) != nil

            if hasStreetNumber || hasStreetKeyword || hasZipCode {
                addressLines.append((index: index, text: line))
            }
        }

        // Combine consecutive address lines
        if !addressLines.isEmpty {
            let combinedAddress = addressLines.map { $0.text }.joined(separator: ", ")
            let usedSet = Set(addressLines.map { $0.index })

            return (
                field: OCRField(type: .address, value: combinedAddress),
                usedIndices: usedSet
            )
        }

        return nil
    }

    private func detectMembershipLevel(in text: String) -> String? {
        // Look for membership level keywords
        let levelKeywords = ["gold", "silver", "bronze", "platinum", "diamond", "premium", "elite", "vip", "basic", "standard"]
        let lowercased = text.lowercased()

        // Check if line contains membership level keywords
        let hasLevelKeyword = levelKeywords.contains { lowercased.contains($0) }
        let hasMembershipWord = lowercased.contains("membership") || lowercased.contains("member") || lowercased.contains("level")

        if hasLevelKeyword && (hasMembershipWord || lowercased.contains("card")) {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Also detect standalone level words if they're Title Case
        if hasLevelKeyword && text.count < 30 {
            let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if words.count <= 3 && words.allSatisfy({ $0.first?.isUppercase == true }) {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    private func detectSeason(in text: String) -> String? {
        // Look for 4-digit year (2020-2099)
        let yearPattern = #"\b(20[2-9][0-9])\b"#

        if let regex = try? NSRegularExpression(pattern: yearPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }

        // Also look for "Season YYYY" or "YYYY Season" patterns
        let seasonPattern = #"(?:Season\s+)?(\d{4})(?:\s+Season)?"#
        if let regex = try? NSRegularExpression(pattern: seasonPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            let year = String(text[range])
            if let yearNum = Int(year), yearNum >= 2020 && yearNum <= 2099 {
                return year
            }
        }

        return nil
    }

    private func detectPIN(in text: String) -> String? {
        let lowercased = text.lowercased()

        // Look for PIN keyword indicators
        let pinKeywords = ["pin", "passcode", "password", "code"]
        let hasPINKeyword = pinKeywords.contains { lowercased.contains($0) }

        // Pattern 1: PIN with label (e.g., "PIN: 5483", "PIN 5483")
        if hasPINKeyword {
            // Extract 4-6 digit number after PIN keyword
            let pattern = #"(?:pin|passcode|password|code)\s*:?\s*(\d{4,6})"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }

        // Pattern 2: Standalone 4 digit number (common for PINs) - be conservative
        // Only match if the line is short and doesn't look like a longer ID
        if text.count <= 15 && !lowercased.contains("member") && !lowercased.contains("card") {
            let pattern = #"^\s*(\d{4})\s*$"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }

        return nil
    }

    private func detectCardType(in text: String) -> String? {
        let lowercased = text.lowercased()

        // Common card type patterns
        let cardTypeKeywords = [
            "pass", "card", "membership", "ticket", "entry", "access",
            "rewards", "loyalty", "program", "club"
        ]

        // Card type prefix/descriptors
        let cardTypeDescriptors = [
            "fun", "gold", "silver", "bronze", "platinum", "diamond",
            "premier", "elite", "vip", "basic", "standard", "premium",
            "annual", "season", "day", "single", "multi", "family"
        ]

        // Check if line contains both a descriptor and a card type keyword
        let hasCardTypeKeyword = cardTypeKeywords.contains { lowercased.contains($0) }
        let hasDescriptor = cardTypeDescriptors.contains { lowercased.contains($0) }

        // Also match standalone card types like "FUN PASS", "GOLD CARD"
        if hasCardTypeKeyword && (hasDescriptor || text.split(separator: " ").count <= 3) {
            // Filter out lines that are too long or contain numbers (likely not card types)
            let hasNumbers = text.rangeOfCharacter(from: .decimalDigits) != nil
            if !hasNumbers && text.count <= 30 {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    private func isLabelOnly(_ text: String) -> Bool {
        // Check if text is just a label (all caps, short, no valuable content)
        let labels = ["LEVEL", "NAME", "SEASON", "MEMBER", "ID", "CARD", "NUMBER", "DATE", "EXPIRES", "VALID", "PIN", "TYPE"]
        let uppercased = text.uppercased()
        return labels.contains(uppercased) || (text == uppercased && text.count < 12 && !text.contains(where: { $0.isNumber }))
    }
}
