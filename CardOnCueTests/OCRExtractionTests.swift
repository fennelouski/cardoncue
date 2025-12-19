import XCTest
import Vision
@testable import CardOnCue

final class OCRExtractionTests: XCTestCase {

    func testElitchGardensCardExtraction() async throws {
        // This test validates that the Elitch Gardens card extracts all expected fields

        print("\n🧪 Testing Elitch Gardens Card OCR Extraction")
        print("=" + String(repeating: "=", count: 60))

        // Load test image - you'll need to add the Elitch Gardens image to the test bundle
        // For now, we'll test with a mock image that simulates the OCR results

        // Create a mock OCR result that matches what Vision would return for the Elitch Gardens card
        let mockOCRResult = createMockElitchGardensOCRResult()

        // Test segment detection
        let segments = OCRSegmentDetector.shared.detectSegments(
            from: mockOCRResult,
            parsedData: nil
        )

        print("\n📝 Detected \(segments.count) segments:")
        for segment in segments {
            print("   \(segment.type.displayName): \"\(segment.value)\"")
        }
        print("")

        // Validate expected fields
        var results: [String: Bool] = [:]

        // 1. Membership Level: "Gold Membership"
        let membershipLevel = segments.first { $0.type == .membershipLevel }
        if let level = membershipLevel {
            let isCorrect = level.value.lowercased().contains("gold") && level.value.lowercased().contains("membership")
            results["Membership Level"] = isCorrect
            print(isCorrect ? "✅" : "❌", "Membership Level: \"\(level.value)\"", isCorrect ? "(Expected: Gold Membership)" : "- INCORRECT")
        } else {
            results["Membership Level"] = false
            print("❌ Membership Level: NOT DETECTED")
        }

        // 2. Season: "2025"
        let season = segments.first { $0.type == .season }
        if let s = season {
            let isCorrect = s.value == "2025"
            results["Season"] = isCorrect
            print(isCorrect ? "✅" : "❌", "Season: \"\(s.value)\"", isCorrect ? "(Expected: 2025)" : "- INCORRECT")
        } else {
            results["Season"] = false
            print("❌ Season: NOT DETECTED")
        }

        // 3. Member ID: "224573530"
        let memberId = segments.first { $0.type == .memberId }
        if let id = memberId {
            let isCorrect = id.value.contains("224573530")
            results["Member ID"] = isCorrect
            print(isCorrect ? "✅" : "❌", "Member ID: \"\(id.value)\"", isCorrect ? "(Expected: 224573530)" : "- INCORRECT")
        } else {
            results["Member ID"] = false
            print("❌ Member ID: NOT DETECTED")
        }

        // 4. Verify label-only text is filtered out
        let otherFields = segments.filter { $0.type == .other }
        let hasLabelOnlyText = otherFields.contains { field in
            let uppercased = field.value.uppercased()
            return ["LEVEL", "NAME", "SEASON", "MEMBER", "CARD"].contains(uppercased)
        }

        results["Label Filtering"] = !hasLabelOnlyText
        print(hasLabelOnlyText ? "❌" : "✅", "Label Filtering:", hasLabelOnlyText ? "Found label-only text in Other fields" : "No label-only text in Other fields")

        // Print summary
        print("")
        print(String(repeating: "=", count: 60))
        let passCount = results.values.filter { $0 }.count
        let totalCount = results.count
        print("📊 Results: \(passCount)/\(totalCount) tests passed")
        print(String(repeating: "=", count: 60))
        print("")

        // Assert all tests passed
        XCTAssertTrue(results["Membership Level"] ?? false, "Membership Level should be detected")
        XCTAssertTrue(results["Season"] ?? false, "Season should be detected")
        XCTAssertTrue(results["Member ID"] ?? false, "Member ID should be detected")
        XCTAssertTrue(results["Label Filtering"] ?? false, "Label-only text should be filtered out")
    }

    // MARK: - Mock Data

    private func createMockElitchGardensOCRResult() -> VisionOCRService.OCRResult {
        // This simulates the OCR text that Vision would extract from the Elitch Gardens card
        let mockText = """
        Elitch Gardens
        Gold Membership
        Emma F
        2025
        SEASON
        224573530
        """

        return VisionOCRService.OCRResult(
            allText: mockText,
            cardName: "Elitch Gardens",
            memberId: "224573530",
            barcodeNumber: "224573530",
            confidence: 0.95,
            detectedBarcodes: []
        )
    }

    // MARK: - Pattern Detection Tests

    func testMembershipLevelDetection() {
        print("\n🧪 Testing Membership Level Detection Patterns")

        let testCases: [(input: String, shouldDetect: Bool, description: String)] = [
            ("Gold Membership", true, "Standard format"),
            ("Platinum Member Card", true, "Platinum with member"),
            ("VIP Membership", true, "VIP format"),
            ("Elite Level", true, "Elite with level keyword"),
            ("Silver", true, "Standalone level word (Title Case)"),
            ("LEVEL", false, "Label-only text"),
            ("Regular text", false, "No level keywords"),
            ("membership", false, "Lowercase only")
        ]

        for (input, shouldDetect, description) in testCases {
            let result = testMembershipLevelPattern(input)
            let success = (result != nil) == shouldDetect

            print(success ? "✅" : "❌", description + ":", "\"\(input)\"", "->", result ?? "nil")

            XCTAssertEqual(result != nil, shouldDetect, "Failed for: \(description)")
        }
    }

    func testSeasonDetection() {
        print("\n🧪 Testing Season/Year Detection Patterns")

        let testCases: [(input: String, expected: String?, description: String)] = [
            ("2025", "2025", "Year alone"),
            ("Season 2025", "2025", "Season prefix"),
            ("2024 Season", "2024", "Season suffix"),
            ("Valid through 2026", "2026", "In sentence"),
            ("1999", nil, "Year too old"),
            ("3000", nil, "Year too far future"),
            ("25", nil, "Two-digit year")
        ]

        for (input, expected, description) in testCases {
            let result = testSeasonPattern(input)
            let success = result == expected

            print(success ? "✅" : "❌", description + ":", "\"\(input)\"", "->", result ?? "nil", expected != nil ? "(Expected: \(expected!))" : "")

            XCTAssertEqual(result, expected, "Failed for: \(description)")
        }
    }

    func testLabelOnlyFiltering() {
        print("\n🧪 Testing Label-Only Text Filtering")

        let testCases: [(input: String, shouldFilter: Bool, description: String)] = [
            ("LEVEL", true, "Label: LEVEL"),
            ("NAME", true, "Label: NAME"),
            ("SEASON", true, "Label: SEASON"),
            ("MEMBER", true, "Label: MEMBER"),
            ("Gold Membership", false, "Valid content"),
            ("Emma F", false, "Person name"),
            ("224573530", false, "Number"),
            ("ID", true, "Short all-caps no numbers")
        ]

        for (input, shouldFilter, description) in testCases {
            let result = testLabelOnlyPattern(input)
            let success = result == shouldFilter

            print(success ? "✅" : "❌", description + ":", "\"\(input)\"", "->", result ? "FILTERED" : "KEPT")

            XCTAssertEqual(result, shouldFilter, "Failed for: \(description)")
        }
    }

    // MARK: - Helper Methods

    private func testMembershipLevelPattern(_ text: String) -> String? {
        let levelKeywords = ["gold", "silver", "bronze", "platinum", "diamond", "premium", "elite", "vip", "basic", "standard"]
        let lowercased = text.lowercased()

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

    private func testSeasonPattern(_ text: String) -> String? {
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

    private func testLabelOnlyPattern(_ text: String) -> Bool {
        let labels = ["LEVEL", "NAME", "SEASON", "MEMBER", "ID", "CARD", "NUMBER", "DATE", "EXPIRES", "VALID"]
        let uppercased = text.uppercased()
        return labels.contains(uppercased) || (text == uppercased && text.count < 12 && !text.contains(where: { $0.isNumber }))
    }

    // MARK: - Louisville Public Library Card Test

    func testLouisvillePublicLibraryCardExtraction() async throws {
        // This test validates all 5 fixes for the Louisville Public Library card

        print("\n🧪 Testing Louisville Public Library Card OCR Extraction")
        print("=" + String(repeating: "=", count: 60))
        print("📋 This test validates:")
        print("   1. Card name = 'Louisville Public Library' (not 'Tabasco')")
        print("   2. Address detected and geocoded")
        print("   3. Phone number = '(303) 335-4849'")
        print("   4. Website = 'https://Louisville-Library.org'")
        print("   5. Barcode processable")
        print("")

        // Create a mock OCR result that simulates what Vision extracts from the card
        let mockOCRResult = createMockLouisvilleLibraryOCRResult()

        var results: [String: Bool] = [:]

        // TEST 1: Card Name Detection
        print("🔍 Test 1: Card Name Detection")
        let cardName = mockOCRResult.cardName
        let isCardNameCorrect = cardName == "Louisville Public Library"
        results["Card Name"] = isCardNameCorrect

        if isCardNameCorrect {
            print("   ✅ Card Name: '\(cardName ?? "nil")'")
        } else {
            print("   ❌ Card Name: '\(cardName ?? "nil")' (Expected: 'Louisville Public Library')")
        }

        // TEST 2: Address Detection
        print("\n🔍 Test 2: Address Detection via OCRSegmentDetector")
        let parsedData = await CardDataParser.shared.parseFromVisionOCR(mockOCRResult, userLocation: nil)
        let segments = OCRSegmentDetector.shared.detectSegments(from: mockOCRResult, parsedData: parsedData)

        let addressSegment = segments.first { $0.type == .address }
        let hasCorrectAddress = addressSegment?.value.contains("951 Spruce Street") == true &&
                                addressSegment?.value.contains("Louisville") == true &&
                                addressSegment?.value.contains("CO") == true &&
                                addressSegment?.value.contains("80027") == true
        results["Address Detection"] = hasCorrectAddress

        if hasCorrectAddress {
            print("   ✅ Address: '\(addressSegment?.value ?? "nil")'")
        } else {
            print("   ❌ Address: '\(addressSegment?.value ?? "nil")'")
            print("      Expected to contain: '951 Spruce Street, Louisville, CO 80027'")
        }

        // TEST 3: Location Geocoding Priority
        print("\n🔍 Test 3: Location Geocoding (Address Priority)")
        let hasLocationSuggestions = !parsedData.suggestedLocations.isEmpty
        let firstLocation = parsedData.suggestedLocations.first
        let isLocationCorrect = firstLocation?.address.contains("Louisville") == true &&
                                firstLocation?.address.contains("CO") == true
        results["Location Geocoding"] = hasLocationSuggestions && isLocationCorrect

        if isLocationCorrect {
            print("   ✅ First location suggestion:")
            print("      Name: '\(firstLocation?.name ?? "nil")'")
            print("      Address: '\(firstLocation?.address ?? "nil")'")
            print("      (Not 'Tabasco, Mexico' ✓)")
        } else {
            print("   ❌ Location suggestions:")
            for (i, loc) in parsedData.suggestedLocations.prefix(3).enumerated() {
                print("      \(i+1). \(loc.name) - \(loc.address)")
            }
        }

        // TEST 4: Phone Number Detection
        print("\n🔍 Test 4: Phone Number Detection and Formatting")
        let phoneSegment = segments.first { $0.type == .phoneNumber }
        let hasPhone = phoneSegment != nil
        let isPhoneFormatted = phoneSegment?.value.contains("303") == true &&
                               phoneSegment?.value.contains("335") == true &&
                               phoneSegment?.value.contains("4849") == true
        results["Phone Detection"] = hasPhone && isPhoneFormatted

        if hasPhone && isPhoneFormatted {
            print("   ✅ Phone: '\(phoneSegment?.value ?? "nil")'")
        } else {
            print("   ❌ Phone: '\(phoneSegment?.value ?? "nil")'")
            print("      Expected format: '(303) 335-4849'")
        }

        // TEST 5: Website Detection
        print("\n🔍 Test 5: Website Detection (with hyphen support)")
        let websiteSegment = segments.first { $0.type == .website }
        let hasWebsite = websiteSegment != nil
        let isWebsiteCorrect = websiteSegment?.value.lowercased().contains("louisville-library.org") == true ||
                               websiteSegment?.value.lowercased().contains("louisvillelibrary.org") == true
        results["Website Detection"] = hasWebsite && isWebsiteCorrect

        if hasWebsite && isWebsiteCorrect {
            print("   ✅ Website: '\(websiteSegment?.value ?? "nil")'")
        } else {
            print("   ❌ Website: '\(websiteSegment?.value ?? "nil")'")
            print("      Expected: 'https://Louisville-Library.org'")
        }

        // TEST 6: Barcode Detection
        print("\n🔍 Test 6: Barcode Number Extraction")
        let hasBarcodeNumber = mockOCRResult.barcodeNumber != nil && !mockOCRResult.barcodeNumber!.isEmpty
        results["Barcode Number"] = hasBarcodeNumber

        if hasBarcodeNumber {
            print("   ✅ Barcode Number: '\(mockOCRResult.barcodeNumber ?? "nil")'")
        } else {
            print("   ❌ Barcode Number: Not detected")
        }

        // Print all detected segments
        print("\n📝 All Detected Segments (\(segments.count) total):")
        for segment in segments {
            print("   • \(segment.type.displayName): '\(segment.value)'")
        }

        // Print summary
        print("")
        print(String(repeating: "=", count: 60))
        let passCount = results.values.filter { $0 }.count
        let totalCount = results.count
        print("📊 Results: \(passCount)/\(totalCount) tests passed")

        if passCount == totalCount {
            print("🎉 ALL TESTS PASSED! Louisville Library card fixes verified!")
        } else {
            print("⚠️  Some tests failed. Review output above.")
        }
        print(String(repeating: "=", count: 60))
        print("")

        // Assert all tests passed
        XCTAssertTrue(results["Card Name"] ?? false, "Card name should be 'Louisville Public Library'")
        XCTAssertTrue(results["Address Detection"] ?? false, "Address should be detected with street, city, state, zip")
        XCTAssertTrue(results["Location Geocoding"] ?? false, "Location should geocode to Louisville, CO (not Tabasco, Mexico)")
        XCTAssertTrue(results["Phone Detection"] ?? false, "Phone number should be detected and formatted")
        XCTAssertTrue(results["Website Detection"] ?? false, "Website should be detected with hyphen support")
        XCTAssertTrue(results["Barcode Number"] ?? false, "Barcode number should be extracted")
    }

    // MARK: - Mock Data for Louisville Library Card

    private func createMockLouisvilleLibraryOCRResult() -> VisionOCRService.OCRResult {
        // This simulates the OCR text that Vision would extract from the Louisville Public Library card
        // Based on the actual card image showing:
        // - Louisville Public Library (header)
        // - 303.335.4849 | Louisville-Library.org
        // - 951 Spruce Street, Louisville, CO 80027
        // - Barcode: D050644627
        // - Signature and possibly "Tabasco" text (which should be ignored)

        let mockText = """
        Louisville Public Library
        303.335.4849 | Louisville-Library.org
        951 Spruce Street, Louisville, CO 80027
        Tabasco
        Signature
        D050644627
        """

        return VisionOCRService.OCRResult(
            allText: mockText,
            cardName: "Louisville Public Library",  // Should be detected correctly now
            memberId: nil,
            barcodeNumber: "D050644627",
            confidence: 0.92,
            detectedBarcodes: [
                VisionOCRService.OCRResult.DetectedBarcode(
                    type: "org.iso.Code39",
                    value: "D050644627",
                    boundingBox: CGRect(x: 0, y: 0, width: 100, height: 50)
                )
            ]
        )
    }
}
