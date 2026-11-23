import Foundation

/// "#RRGGBB" 글자와 RGB(0~1) 값을 서로 바꾼다.
struct RGB: Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
}

enum HexColor {
    static func parse(_ text: String) -> RGB? {
        var s = text.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        return RGB(red: Double((value >> 16) & 0xFF) / 255,
                   green: Double((value >> 8) & 0xFF) / 255,
                   blue: Double(value & 0xFF) / 255)
    }

    static func format(_ rgb: RGB) -> String {
        func byte(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        let n = (byte(rgb.red) << 16) | (byte(rgb.green) << 8) | byte(rgb.blue)
        let hex = String(n, radix: 16, uppercase: true)
        return "#" + String(repeating: "0", count: 6 - hex.count) + hex
    }

    /// 상대 밝기(WCAG). 0 = 검정, 1 = 흰색
    static func luminance(_ rgb: RGB) -> Double {
        func linear(_ c: Double) -> Double {
            let v = min(max(c, 0), 1)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.red) + 0.7152 * linear(rgb.green) + 0.0722 * linear(rgb.blue)
    }

    /// 이 바탕에서 검은 글자가 흰 글자보다 대비가 크면 true(밝은 바탕 → 어두운 글자)
    static func prefersDarkText(on rgb: RGB) -> Bool {
        let l = luminance(rgb)
        return (l + 0.05) / 0.05 > 1.05 / (l + 0.05)
    }
}
