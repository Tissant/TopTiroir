/// 서랍 열기 단축키. modifiers는 Carbon 값(cmdKey 등)을 그대로 쓴다.
struct Shortcut: Equatable, Sendable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let f12 = Shortcut(keyCode: 111, modifiers: 0)
    static let escapeKeyCode: UInt32 = 53

    /// Carbon 수식 키 값(Carbon.HIToolbox의 cmdKey·shiftKey·optionKey·controlKey와 같은 숫자)
    enum Modifier {
        static let command: UInt32 = 0x0100
        static let shift: UInt32 = 0x0200
        static let option: UInt32 = 0x0800
        static let control: UInt32 = 0x1000
        static let all = command | shift | option | control
    }

    /// 눌린 키를 단축키로 쓸 수 있는지
    enum Check: Equatable, Sendable {
        case ok
        case cancel          // esc: 바꾸기 취소
        case needsModifier   // 글자·숫자 키는 ⌘ 또는 ⌃와 함께
        case unsupported     // 이름을 모르는 키
    }

    static func check(keyCode: UInt32, modifiers: UInt32) -> Check {
        if keyCode == escapeKeyCode { return .cancel }
        guard keyName(keyCode) != nil else { return .unsupported }
        if functionKeyCodes.contains(keyCode) { return .ok }
        // ⌥·⇧만 쓰는 단축키는 macOS가 등록을 막고, 글자 키만 누르면 타자를 가로채므로 ⌘ 또는 ⌃가 있어야 한다.
        let m = modifiers & Modifier.all
        return (m & (Modifier.command | Modifier.control)) != 0 ? .ok : .needsModifier
    }

    /// 화면에 보일 이름. 예: "F12", "⌃⌥Space", "⌘⇧K"
    var displayName: String {
        var s = ""
        if modifiers & Modifier.control != 0 { s += "⌃" }
        if modifiers & Modifier.option != 0 { s += "⌥" }
        if modifiers & Modifier.shift != 0 { s += "⇧" }
        if modifiers & Modifier.command != 0 { s += "⌘" }
        return s + (Self.keyName(keyCode) ?? "키 \(keyCode)")
    }

    /// 저장한 숫자에서 되살린다. 잘못된 값이면 F12.
    static func stored(keyCode: Int, modifiers: Int) -> Shortcut {
        guard keyCode >= 0, keyCode <= 0xFFFF, modifiers >= 0 else { return .f12 }
        let s = Shortcut(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers) & Modifier.all)
        return check(keyCode: s.keyCode, modifiers: s.modifiers) == .ok ? s : .f12
    }

    // MARK: 키 이름 (Mac 키 코드 → 이름)

    static let functionKeyCodes: Set<UInt32> = Set(functionKeys.keys)

    private static let functionKeys: [UInt32: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
    ]

    private static let otherKeys: [UInt32: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I", 38: "J",
        40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T",
        32: "U", 9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
        29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
        27: "-", 24: "=", 33: "[", 30: "]", 42: "\\", 41: ";", 39: "'", 43: ",", 47: ".", 44: "/", 50: "`",
        49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
        // 키패드 숫자(저장할 때는 윗줄 숫자로 바뀜)
        82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6", 89: "7", 91: "8", 92: "9",
    ]

    static func keyName(_ keyCode: UInt32) -> String? {
        functionKeys[keyCode] ?? otherKeys[keyCode]
    }
}
