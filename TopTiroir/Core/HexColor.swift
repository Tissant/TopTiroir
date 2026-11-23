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
}
