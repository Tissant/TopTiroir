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

    /// 같은 색에서 밝은 색(하이라이트): 흰색 쪽으로 amount만큼
    static func lightened(_ rgb: RGB, by amount: Double) -> RGB {
        let a = min(max(amount, 0), 1)
        func mix(_ c: Double) -> Double { c + (1 - c) * a }
        return RGB(red: mix(rgb.red), green: mix(rgb.green), blue: mix(rgb.blue))
    }

    /// 색상환에서 degrees만큼 돌린 색(밝기·채도 유지). 오로라 그라데이션의 비슷한 색들.
    static func hueShifted(_ rgb: RGB, by degrees: Double) -> RGB {
        let r = rgb.red, g = rgb.green, b = rgb.blue
        let maxV = max(r, g, b), minV = min(r, g, b), d = maxV - minV
        var h = 0.0
        if d > 0 {
            if maxV == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
            else if maxV == g { h = (b - r) / d + 2 }
            else { h = (r - g) / d + 4 }
            h *= 60
        }
        let s = maxV == 0 ? 0 : d / maxV, v = maxV
        var nh = (h + degrees).truncatingRemainder(dividingBy: 360)
        if nh < 0 { nh += 360 }
        let c = v * s, x = c * (1 - abs((nh / 60).truncatingRemainder(dividingBy: 2) - 1)), m = v - c
        let (r1, g1, b1): (Double, Double, Double)
        switch nh {
        case ..<60: (r1, g1, b1) = (c, x, 0)
        case ..<120: (r1, g1, b1) = (x, c, 0)
        case ..<180: (r1, g1, b1) = (0, c, x)
        case ..<240: (r1, g1, b1) = (0, x, c)
        case ..<300: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        return RGB(red: r1 + m, green: g1 + m, blue: b1 + m)
    }
}
