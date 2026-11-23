/// 바꿀 수 있는 단축키 묶음(서랍 열기·탭 이동·종료)과 검사·해석. AppKit 없이 숫자만 다룬다.

/// 바꿀 수 있는 단축키 항목
enum ShortcutAction: String, CaseIterable, Identifiable, Sendable {
    case openDrawer, tabNotes, tabFavorites, tabSettings, quit
    var id: String { rawValue }

    var title: String {
        switch self {
        case .openDrawer: "서랍 열기·닫기"
        case .tabNotes: "메모/할 일 탭"
        case .tabFavorites: "즐겨찾기 탭"
        case .tabSettings: "설정 탭"
        case .quit: "TopTiroir 종료"
        }
    }

    var defaultShortcut: Shortcut {
        switch self {
        case .openDrawer: .f12
        case .tabNotes: Shortcut(keyCode: 122, modifiers: 0)      // F1
        case .tabFavorites: Shortcut(keyCode: 120, modifiers: 0)  // F2
        case .tabSettings: Shortcut(keyCode: 99, modifiers: 0)    // F3
        case .quit: Shortcut(keyCode: 12, modifiers: Shortcut.Modifier.command) // ⌘Q
        }
    }

    var tab: DrawerTab? {
        switch self {
        case .tabNotes: .notes
        case .tabFavorites: .favorites
        case .tabSettings: .settings
        default: nil
        }
    }
}

/// 보기 전용(바꿀 수 없는) 단축키. 다른 항목이 이 키를 쓰지 못하게 막는 데도 쓴다.
struct FixedShortcut: Sendable {
    let title: String
    let keys: String
    let shortcut: Shortcut?   // 키 하나로 나타낼 수 없는 것(더블클릭 등)은 nil

    static let drawer: [FixedShortcut] = [
        FixedShortcut(title: "서랍 닫기 · 고치기 취소", keys: "esc", shortcut: Shortcut(keyCode: 53, modifiers: 0)),
    ]

    static let editing: [FixedShortcut] = {
        let cmd = Shortcut.Modifier.command, shift = Shortcut.Modifier.shift
        return [
            FixedShortcut(title: "되돌리기", keys: "⌘Z", shortcut: Shortcut(keyCode: 6, modifiers: cmd)),
            FixedShortcut(title: "다시 실행", keys: "⇧⌘Z", shortcut: Shortcut(keyCode: 6, modifiers: cmd | shift)),
            FixedShortcut(title: "잘라내기", keys: "⌘X", shortcut: Shortcut(keyCode: 7, modifiers: cmd)),
            FixedShortcut(title: "복사", keys: "⌘C", shortcut: Shortcut(keyCode: 8, modifiers: cmd)),
            FixedShortcut(title: "붙여넣기", keys: "⌘V", shortcut: Shortcut(keyCode: 9, modifiers: cmd)),
            FixedShortcut(title: "전체 선택", keys: "⌘A", shortcut: Shortcut(keyCode: 0, modifiers: cmd)),
            FixedShortcut(title: "들여쓰기(메모)", keys: "Tab", shortcut: Shortcut(keyCode: 48, modifiers: 0)),
            FixedShortcut(title: "내어쓰기(메모)", keys: "⇧Tab", shortcut: Shortcut(keyCode: 48, modifiers: shift)),
            FixedShortcut(title: "할 일 추가 · 고치기 완료", keys: "↩", shortcut: Shortcut(keyCode: 36, modifiers: 0)),
            FixedShortcut(title: "할 일 고치기 시작", keys: "더블클릭", shortcut: nil),
        ]
    }()

    static var all: [FixedShortcut] { drawer + editing }
}

/// 단축키를 바꿀 때 검사 결과
enum ShortcutCheck: Equatable, Sendable {
    case ok
    case cancel                 // esc: 바꾸기 취소
    case needsModifier          // 서랍 열기: 글자·숫자 키는 ⌘ 또는 ⌃와 함께
    case needsCommand           // 종료: ⌘와 함께
    case unsupported            // 이름을 모르는 키
    case conflict(String)       // 이미 다른 곳에서 쓰는 키(그 이름)
}

/// 서랍 안에서 키를 눌렀을 때 할 일
enum LocalShortcutResult: Equatable, Sendable {
    case quit
    case showTab(DrawerTab)
}

struct ShortcutSet: Equatable, Sendable {
    private(set) var values: [ShortcutAction: Shortcut]

    static var defaults: ShortcutSet {
        ShortcutSet(values: Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map { ($0, $0.defaultShortcut) }))
    }

    subscript(action: ShortcutAction) -> Shortcut {
        get { values[action] ?? action.defaultShortcut }
        set { values[action] = newValue.normalized }
    }

    func isDefault(_ action: ShortcutAction) -> Bool { self[action] == action.defaultShortcut }
    var isAllDefault: Bool { ShortcutAction.allCases.allSatisfy(isDefault) }

    /// action에 candidate를 넣어도 되는지
    func check(_ candidate: Shortcut, for action: ShortcutAction) -> ShortcutCheck {
        let s = candidate.normalized
        if s.keyCode == Shortcut.escapeKeyCode { return .cancel }
        guard Shortcut.keyName(s.keyCode) != nil else { return .unsupported }
        switch action {
        case .openDrawer:
            if Shortcut.check(keyCode: s.keyCode, modifiers: s.modifiers) == .needsModifier { return .needsModifier }
        case .quit:
            if s.modifiers & Shortcut.Modifier.command == 0 { return .needsCommand }
        case .tabNotes, .tabFavorites, .tabSettings:
            break // 커서가 없을 때만 쓰므로 수정키 없는 한 키도 된다
        }
        for fixed in FixedShortcut.all where fixed.shortcut == s {
            return .conflict(fixed.title)
        }
        for other in ShortcutAction.allCases where other != action && self[other] == s {
            return .conflict(other.title)
        }
        return .ok
    }

    /// 서랍 안에서 눌린 키 해석. 탭 이동은 커서와 상관없이 동작한다.
    /// 다만 사용자가 글자·숫자 한 키(수정키 없음)로 바꿨다면, 입력칸에 커서가 있을 땐 글자로 들어가야 하므로 건너뛴다.
    func localAction(keyCode: UInt16, modifiers: UInt32, textFocused: Bool) -> LocalShortcutResult? {
        let pressed = Shortcut(keyCode: UInt32(keyCode), modifiers: modifiers & Shortcut.Modifier.all).normalized
        if pressed == self[.quit] { return .quit }
        for action in [ShortcutAction.tabNotes, .tabFavorites, .tabSettings] where pressed == self[action] {
            if textFocused && pressed.typesCharacter { return nil }
            return action.tab.map(LocalShortcutResult.showTab)
        }
        return nil
    }

    /// 예전 기본값(1·2·3)이 그대로 저장돼 있으면 새 기본값(F1·F2·F3)으로 바꿀 대상
    static func isOldTabDefault(_ s: Shortcut, for action: ShortcutAction) -> Bool {
        let old: [ShortcutAction: UInt32] = [.tabNotes: 18, .tabFavorites: 19, .tabSettings: 20]
        guard let code = old[action] else { return false }
        return s == Shortcut(keyCode: code, modifiers: 0)
    }

    // MARK: 저장 (키 코드 + 수정키를 숫자 하나로)

    static func pack(_ s: Shortcut) -> Int { Int(s.keyCode) | (Int(s.modifiers) << 16) }

    static func unpack(_ value: Int, fallback: Shortcut) -> Shortcut {
        guard value >= 0 else { return fallback }
        let s = Shortcut(keyCode: UInt32(value & 0xFFFF), modifiers: UInt32((value >> 16) & 0xFFFF) & Shortcut.Modifier.all)
        return Shortcut.keyName(s.keyCode) == nil ? fallback : s.normalized
    }
}

extension Shortcut {
    /// 키패드 숫자는 윗줄 숫자와 같은 키로 본다(1과 키패드 1 모두 메모/할 일 탭).
    private static let keypadDigits: [UInt32: UInt32] = [
        82: 29, 83: 18, 84: 19, 85: 20, 86: 21, 87: 23, 88: 22, 89: 26, 91: 28, 92: 25,
    ]

    /// 입력칸에서 글자를 넣는 키인지(수정키 없이 또는 ⇧만, 기능 키·화살표 등 제외)
    var typesCharacter: Bool {
        if Shortcut.functionKeyCodes.contains(keyCode) { return false }
        if modifiers & (Modifier.command | Modifier.control | Modifier.option) != 0 { return false }
        let nonTyping: Set<UInt32> = [123, 124, 125, 126, 115, 119, 116, 121, 117, 51, 36, 48]
        return !nonTyping.contains(keyCode)
    }

    var normalized: Shortcut {
        guard let row = Shortcut.keypadDigits[keyCode] else { return self }
        return Shortcut(keyCode: row, modifiers: modifiers)
    }
}
