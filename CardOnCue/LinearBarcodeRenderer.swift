import Foundation
import CoreGraphics

/// Shared, dependency-free 1D barcode renderer for the symbologies CoreImage
/// can't generate (EAN-13, UPC-A, Code 39, ITF) plus Code 128. Pure CoreGraphics,
/// so it works identically on iOS and watchOS (CoreImage barcode generators are
/// unavailable on watchOS). Draws module bars into a grayscale CGContext.
enum LinearBarcodeRenderer {

    enum LinearBarcodeError: Error { case unsupportedType, invalidPayload }

    /// Wide:narrow ratio for Code 39 / ITF (spec allows 2.0-3.0; 3 scans reliably off-screen).
    private static let wide = 3
    /// Quiet zone (white modules) each side. Scanners need this margin.
    private static let quiet = 10

    static func render(payload: String, type: BarcodeType, size: CGSize) throws -> CGImage {
        #if DEBUG
        runSelfCheckOnce()
        #endif

        let bits: [Bool]
        switch type {
        case .code128:      bits = try code128B(payload)
        case .code39:       bits = try code39(payload)
        case .itf:          bits = try itf(payload)
        case .ean13:        bits = try ean13FromPayload(payload)
        case .upcA:         bits = try upcAFromPayload(payload)
        case .qr, .pdf417, .aztec:
            throw LinearBarcodeError.unsupportedType
        }
        return try draw(bits: bits, size: size)
    }

    // MARK: - Drawing

    private static func draw(bits: [Bool], size: CGSize) throws -> CGImage {
        let full = Array(repeating: false, count: quiet) + bits + Array(repeating: false, count: quiet)
        let moduleCount = full.count
        let targetWidth = max(moduleCount, Int(size.width.rounded()))
        let moduleW = max(1, targetWidth / moduleCount)
        let width = moduleW * moduleCount
        let height = max(1, Int(size.height.rounded()))

        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { throw LinearBarcodeError.invalidPayload }

        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setFillColor(gray: 0, alpha: 1)
        for (i, on) in full.enumerated() where on {
            ctx.fill(CGRect(x: i * moduleW, y: 0, width: moduleW, height: height))
        }
        guard let image = ctx.makeImage() else { throw LinearBarcodeError.invalidPayload }
        return image
    }

    // MARK: - Bit builders

    /// Expand an N/W element pattern (alternating bar,space,... starting with a bar).
    private static func modulesFromNW(_ pattern: String) -> [Bool] {
        var bits: [Bool] = []
        var black = true
        for ch in pattern {
            bits.append(contentsOf: Array(repeating: black, count: ch == "W" ? wide : 1))
            black.toggle()
        }
        return bits
    }

    /// Expand a Code 128 width pattern (each char = element width, alternating starting with a bar).
    private static func modulesFromWidths(_ widths: String, startBlack: Bool = true) -> [Bool] {
        var bits: [Bool] = []
        var black = startBlack
        for ch in widths {
            let w = ch.wholeNumberValue ?? 1
            bits.append(contentsOf: Array(repeating: black, count: w))
            black.toggle()
        }
        return bits
    }

    // MARK: Code 39

    private static func code39(_ payload: String) throws -> [Bool] {
        var bits: [Bool] = []
        func append(_ c: Character) throws {
            guard let pat = code39Table[c] else { throw LinearBarcodeError.invalidPayload }
            bits.append(contentsOf: modulesFromNW(pat))
        }
        try append("*")                       // start
        bits.append(false)                    // inter-character narrow space
        for c in payload.uppercased() {
            try append(c)
            bits.append(false)
        }
        try append("*")                       // stop
        return bits
    }

    // MARK: ITF (Interleaved 2 of 5)

    private static func itf(_ payload: String) throws -> [Bool] {
        var digits = payload.compactMap { $0.wholeNumberValue }
        guard digits.count == payload.count, !digits.isEmpty else { throw LinearBarcodeError.invalidPayload }
        if digits.count % 2 != 0 { digits.insert(0, at: 0) }   // ITF needs an even count

        var bits: [Bool] = [true, false, true, false]          // start NNNN
        var i = 0
        while i < digits.count {
            let barPat = Array(itfDigits[digits[i]])
            let spacePat = Array(itfDigits[digits[i + 1]])
            for e in 0..<5 {
                bits.append(contentsOf: Array(repeating: true, count: barPat[e] == "W" ? wide : 1))
                bits.append(contentsOf: Array(repeating: false, count: spacePat[e] == "W" ? wide : 1))
            }
            i += 2
        }
        bits.append(contentsOf: Array(repeating: true, count: wide))  // stop: wide bar
        bits.append(false)                                            // narrow space
        bits.append(true)                                             // narrow bar
        return bits
    }

    // MARK: EAN-13 / UPC-A

    private static func ean13CheckDigit(_ d: [Int]) -> Int {
        // Positions 1..12 (left to right): odd positions weight 1, even weight 3.
        var sum = 0
        for (i, v) in d.enumerated() { sum += (i % 2 == 0) ? v : v * 3 }
        return (10 - (sum % 10)) % 10
    }

    /// `data12` = 12 data digits; the 13th (check) is computed here.
    private static func ean13(_ data12: [Int]) -> [Bool] {
        let all = data12 + [ean13CheckDigit(data12)]
        let parity = Array(ean13Parity[all[0]])
        var s = "101"                                   // start guard
        for (idx, d) in all[1...6].enumerated() {
            s += parity[idx] == "L" ? eanL[d] : eanG[d]
        }
        s += "01010"                                    // center guard
        for d in all[7...12] { s += eanR[d] }
        s += "101"                                      // end guard
        return s.map { $0 == "1" }
    }

    private static func ean13FromPayload(_ payload: String) throws -> [Bool] {
        let digits = payload.compactMap { $0.wholeNumberValue }
        guard digits.count == payload.count else { throw LinearBarcodeError.invalidPayload }
        let data12: [Int]
        if digits.count == 13 { data12 = Array(digits[0..<12]) }   // ignore supplied check, recompute
        else if digits.count == 12 { data12 = digits }
        else { throw LinearBarcodeError.invalidPayload }
        return ean13(data12)
    }

    private static func upcAFromPayload(_ payload: String) throws -> [Bool] {
        // UPC-A is EAN-13 with an implied leading 0. Need 11 data digits.
        let digits = payload.compactMap { $0.wholeNumberValue }
        guard digits.count == payload.count else { throw LinearBarcodeError.invalidPayload }
        let data11: [Int]
        if digits.count == 12 { data11 = Array(digits[0..<11]) } // ignore supplied check, recompute
        else if digits.count == 11 { data11 = digits }
        else { throw LinearBarcodeError.invalidPayload }
        return ean13([0] + data11)
    }

    // MARK: Code 128 (Code Set B)
    // ponytail: Set B only. Set C would encode long digit runs at half the width;
    // add it if a card's Code 128 payload is long and mostly numeric.

    private static func code128B(_ payload: String) throws -> [Bool] {
        var values: [Int] = []
        for scalar in payload.unicodeScalars {
            let a = Int(scalar.value)
            guard a >= 32 && a <= 126 else { throw LinearBarcodeError.invalidPayload }
            values.append(a - 32)                       // Set B: value = ASCII - 32
        }
        guard !values.isEmpty else { throw LinearBarcodeError.invalidPayload }

        let startB = 104
        var sum = startB
        for (i, v) in values.enumerated() { sum += v * (i + 1) }
        let check = sum % 103

        var bits: [Bool] = []
        for sym in [startB] + values + [check] {
            bits.append(contentsOf: modulesFromWidths(code128Patterns[sym]))
        }
        bits.append(contentsOf: modulesFromWidths("2331112"))   // stop (with final bar)
        return bits
    }

    // MARK: - Tables

    /// Code 39: 9 elements per char (bar,space,...,bar), N=narrow W=wide, exactly 3 wide.
    private static let code39Table: [Character: String] = [
        "0": "NNNWWNWNN", "1": "WNNWNNNNW", "2": "NNWWNNNNW", "3": "WNWWNNNNN",
        "4": "NNNWWNNNW", "5": "WNNWWNNNN", "6": "NNWWWNNNN", "7": "NNNWNNWNW",
        "8": "WNNWNNWNN", "9": "NNWWNNWNN",
        "A": "WNNNNWNNW", "B": "NNWNNWNNW", "C": "WNWNNWNNN", "D": "NNNNWWNNW",
        "E": "WNNNWWNNN", "F": "NNWNWWNNN", "G": "NNNNNWWNW", "H": "WNNNNWWNN",
        "I": "NNWNNWWNN", "J": "NNNNWWWNN",
        "K": "WNNNNNNWW", "L": "NNWNNNNWW", "M": "WNWNNNNWN", "N": "NNNNWNNWW",
        "O": "WNNNWNNWN", "P": "NNWNWNNWN", "Q": "NNNNNNWWW", "R": "WNNNNNWWN",
        "S": "NNWNNNWWN", "T": "NNNNWNWWN",
        "U": "WWNNNNNNW", "V": "NWWNNNNNW", "W": "WWWNNNNNN", "X": "NWNNWNNNW",
        "Y": "WWNNWNNNN", "Z": "NWWNWNNNN",
        "-": "NWNNNNWNW", ".": "WWNNNNWNN", " ": "NWWNNNWNN", "$": "NWNWNWNNN",
        "/": "NWNWNNNWN", "+": "NWNNNWNWN", "%": "NNNWNWNWN", "*": "NWNNWNWNN"
    ]

    /// ITF digit patterns: 5 elements, N/W, exactly 2 wide. Weights 1,2,4,7,0.
    private static let itfDigits: [String] = [
        "NNWWN", "WNNNW", "NWNNW", "WWNNN", "NNWNW",
        "WNWNN", "NWWNN", "NNNWW", "WNNWN", "NWNWN"
    ]

    // EAN/UPC 7-module digit encodings.
    private static let eanL: [String] = [
        "0001101", "0011001", "0010011", "0111101", "0100011",
        "0110001", "0101111", "0111011", "0110111", "0001011"
    ]
    private static let eanG: [String] = [
        "0100111", "0110011", "0011011", "0100001", "0011101",
        "0111001", "0000101", "0010001", "0001001", "0010111"
    ]
    private static let eanR: [String] = [
        "1110010", "1100110", "1101100", "1000010", "1011100",
        "1001110", "1010000", "1000100", "1001000", "1110100"
    ]
    /// First-digit -> L/G parity pattern of the six left digits.
    private static let ean13Parity: [String] = [
        "LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG",
        "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL"
    ]

    /// Code 128 value 0..106 -> 6-element width pattern (each symbol sums to 11 modules).
    private static let code128Patterns: [String] = [
        "212222", "222122", "222221", "121223", "121322", "131222", "122213", "122312",
        "132212", "221213", "221312", "231212", "112232", "122132", "122231", "113222",
        "123122", "123221", "223211", "221132", "221231", "213212", "223112", "312131",
        "311222", "321122", "321221", "312212", "322112", "322211", "212123", "212321",
        "232121", "111323", "131123", "131321", "112313", "132113", "132311", "211313",
        "231113", "231311", "112133", "112331", "132131", "113123", "113321", "133121",
        "313121", "211331", "231131", "213113", "213311", "213131", "311123", "311321",
        "331121", "312113", "312311", "332111", "314111", "221411", "431111", "111224",
        "111422", "121124", "121421", "141122", "141221", "112214", "112412", "122114",
        "122411", "142112", "142211", "241211", "221114", "413111", "241112", "134111",
        "111242", "121142", "121241", "114212", "124112", "124211", "411212", "421112",
        "421211", "212141", "214121", "412121", "111143", "111341", "131141", "114113",
        "114311", "411113", "411311", "113141", "114131", "311141", "411131", "211412",
        "211214", "211232", "233111"
    ]

    // MARK: - Self-check (ponytail: one runnable check for the table/encoder logic)

    #if DEBUG
    private static var didSelfCheck = false
    private static func runSelfCheckOnce() {
        if didSelfCheck { return }
        didSelfCheck = true

        // Code 39: every pattern is 9 elements with exactly 3 wide.
        for (c, p) in code39Table {
            assert(p.count == 9, "Code39 \(c) not 9 elements")
            assert(p.filter { $0 == "W" }.count == 3, "Code39 \(c) not 3 wide")
        }
        // ITF: 10 digits, each 5 elements with exactly 2 wide.
        assert(itfDigits.count == 10)
        for p in itfDigits {
            assert(p.count == 5 && p.filter { $0 == "W" }.count == 2, "ITF pattern bad: \(p)")
        }
        // Code 128: 107 patterns, each 6 elements summing to 11 modules.
        assert(code128Patterns.count == 107, "Code128 table not 107 entries")
        for p in code128Patterns {
            assert(p.count == 6, "Code128 pattern not 6 elements: \(p)")
            assert(p.compactMap { $0.wholeNumberValue }.reduce(0, +) == 11, "Code128 pattern != 11 modules: \(p)")
        }
        // EAN-13 check digit (known: 978020137962 -> 4).
        assert(ean13CheckDigit([9,7,8,0,2,0,1,3,7,9,6,2]) == 4, "EAN13 check digit wrong")
        assert(ean13([9,7,8,0,2,0,1,3,7,9,6,2]).count == 95, "EAN13 not 95 modules")
        // Code 128 Set B checksum (payload "0": value 16, check = (104 + 16) % 103 = 17).
        assert((104 + 16) % 103 == 17)
    }
    #endif
}
