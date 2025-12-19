#!/usr/bin/env swift

import Foundation
import UIKit
import Vision

// This test script validates OCR extraction for the Elitch Gardens card
// Usage: swift TestOCRExtraction.swift <path_to_image>

print("🧪 OCR Extraction Test")
print("=" * 50)

// Get image path from command line or use default
let imagePath: String
if CommandLine.arguments.count > 1 {
    imagePath = CommandLine.arguments[1]
} else {
    print("❌ Error: Please provide an image path")
    print("Usage: swift TestOCRExtraction.swift <path_to_image>")
    exit(1)
}

// Load the image
guard let image = UIImage(contentsOfFile: imagePath) else {
    print("❌ Error: Could not load image at path: \(imagePath)")
    exit(1)
}

print("✅ Loaded image: \(imagePath)")
print("   Size: \(image.size.width) x \(image.size.height)")
print("   Orientation: \(image.imageOrientation.rawValue)")
print("")

// Perform OCR
print("🔍 Performing OCR...")

guard let cgImage = image.cgImage else {
    print("❌ Error: Could not get CGImage")
    exit(1)
}

let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true

var allText = ""
var textLines: [String] = []

do {
    try requestHandler.perform([request])

    guard let observations = request.results else {
        print("❌ No OCR results")
        exit(1)
    }

    print("✅ Found \(observations.count) text observations")
    print("")

    // Extract all text
    for observation in observations {
        guard let candidate = observation.topCandidates(1).first else { continue }
        textLines.append(candidate.string)
        allText += candidate.string + "\n"
    }

    print("📝 Full OCR Text:")
    print("-" * 50)
    print(allText)
    print("-" * 50)
    print("")

} catch {
    print("❌ OCR Error: \(error.localizedDescription)")
    exit(1)
}

// Now test field detection patterns
print("🎯 Testing Field Detection:")
print("")

// Helper to test regex patterns
func testPattern(name: String, pattern: String, text: String, options: NSRegularExpression.Options = []) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
        print("   ❌ Invalid regex pattern")
        return nil
    }

    if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
        let captureRange = match.range(at: 1)
        let rangeToUse = captureRange.location != NSNotFound ? captureRange : match.range
        if let range = Range(rangeToUse, in: text) {
            let result = String(text[range])
            print("   ✅ \(name): \"\(result)\"")
            return result
        }
    }

    print("   ❌ \(name): Not found")
    return nil
}

// Test each detection pattern
var detectedFields: [String: String] = [:]

// 1. Test membership level detection
print("1️⃣ Membership Level Detection:")
let levelKeywords = ["gold", "silver", "bronze", "platinum", "diamond", "premium", "elite", "vip", "basic", "standard"]
for line in textLines {
    let lowercased = line.lowercased()
    let hasLevelKeyword = levelKeywords.contains { lowercased.contains($0) }
    let hasMembershipWord = lowercased.contains("membership") || lowercased.contains("member") || lowercased.contains("level")

    if hasLevelKeyword && (hasMembershipWord || lowercased.contains("card")) {
        detectedFields["Membership Level"] = line.trimmingCharacters(in: .whitespacesAndNewlines)
        print("   ✅ Found: \"\(line)\"")
        break
    }
}
if detectedFields["Membership Level"] == nil {
    print("   ❌ Not found")
}
print("")

// 2. Test season/year detection
print("2️⃣ Season/Year Detection:")
let yearPattern = #"\b(20[2-9][0-9])\b"#
for line in textLines {
    if let year = testPattern(name: "Year", pattern: yearPattern, text: line) {
        detectedFields["Season"] = year
        break
    }
}
print("")

// 3. Test member ID detection
print("3️⃣ Member ID Detection:")
let idPatterns = [
    #"(?:ID|Member|Card|Account|Number)\s*[:#]?\s*([A-Z0-9-]{5,})"#,
    #"\b([A-Z0-9]{8,})\b"#,
    #"\b(\d{8,})\b"#
]
for line in textLines {
    for pattern in idPatterns {
        if let id = testPattern(name: "ID Pattern", pattern: pattern, text: line, options: .caseInsensitive) {
            detectedFields["Member ID"] = id
            break
        }
    }
    if detectedFields["Member ID"] != nil { break }
}
print("")

// 4. Test person name detection (simple heuristic)
print("4️⃣ Person Name Detection:")
// Look for short lines with 1-3 words, proper case
for line in textLines {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

    // Skip if it's a known keyword
    let skipKeywords = ["gold", "membership", "elitch", "gardens", "season", "level"]
    if words.count >= 1 && words.count <= 3 {
        let lowercased = trimmed.lowercased()
        let hasSkipKeyword = skipKeywords.contains { lowercased.contains($0) }

        if !hasSkipKeyword && words.allSatisfy({ $0.first?.isUppercase == true }) {
            detectedFields["Person Name"] = trimmed
            print("   ✅ Found: \"\(trimmed)\"")
            break
        }
    }
}
if detectedFields["Person Name"] == nil {
    print("   ❌ Not found")
}
print("")

// Summary
print("=" * 50)
print("📊 Detection Summary:")
print("")

let expectedFields = [
    "Membership Level": "Gold Membership",
    "Season": "2025",
    "Member ID": "224573530",
    "Person Name": "Emma F"
]

var passCount = 0
var failCount = 0

for (field, expectedValue) in expectedFields {
    if let detected = detectedFields[field] {
        if detected.contains(expectedValue) || expectedValue.contains(detected) {
            print("✅ \(field): \"\(detected)\" (Expected: \"\(expectedValue)\")")
            passCount += 1
        } else {
            print("⚠️  \(field): \"\(detected)\" (Expected: \"\(expectedValue)\")")
            failCount += 1
        }
    } else {
        print("❌ \(field): NOT DETECTED (Expected: \"\(expectedValue)\")")
        failCount += 1
    }
}

print("")
print("=" * 50)
print("🎯 Test Results: \(passCount) passed, \(failCount) failed")

if failCount == 0 {
    print("✅ ALL TESTS PASSED!")
    exit(0)
} else {
    print("❌ SOME TESTS FAILED")
    exit(1)
}
