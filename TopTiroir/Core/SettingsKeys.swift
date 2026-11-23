/// 설정 이름(UserDefaults 키)과 기본값. 화면(@AppStorage)과 동작 코드가 같은 값을 쓰도록 한곳에 모은다.
enum SettingsKey {
    static let hideNotch = "hideNotch"
    static let roundCorners = "roundCorners"
    static let bandColor = "bandColor"
    static let drawerScale = "drawerScale"
    static let notchOpenMode = "notchOpenMode"
    static let closeMode = "closeMode"
    static let drawerOpacity = "drawerOpacity"
    static let textScale = "textScale"
    static let indentWidth = "indentWidth"
    static let drawerColorMode = "drawerColorMode"
    static let drawerAppearance = "drawerAppearance"
    static let drawerColor = "drawerColor"
    static let textOpacity = "textOpacity"
    static let openTabMode = "openTabMode"
    static let lastTab = "lastTab"
    static let notesHeight = "notesHeight"
    static let hotKeyCode = "hotKeyCode"
    static let hotKeyModifiers = "hotKeyModifiers"
}

enum SettingsDefault {
    static let hideNotch = true
    static let roundCorners = false
    static let bandColor = "#0B0C10"
    static let drawerScale = 1.0
    static let notchOpenMode = NotchOpenMode.click.rawValue
    static let closeMode = CloseMode.outsideOrEsc.rawValue
    static let drawerOpacity = 1.0
    static let textScale = 1.0
    static let indentWidth = Indent.defaultWidth
    static let drawerColorMode = DrawerColorMode.standard.rawValue
    static let drawerAppearance = DrawerAppearance.system.rawValue
    static let drawerColor = "#2E3240"
    static let textOpacity = 1.0
    static let openTabMode = OpenTabMode.last.rawValue
    static let lastTab = DrawerTab.notes.rawValue
    static let notesHeight = Double(Layout.notesDefaultHeight)
    static let hotKeyCode = Int(Shortcut.f12.keyCode)
    static let hotKeyModifiers = Int(Shortcut.f12.modifiers)
}

/// 노치에서 서랍 열기 방식
enum NotchOpenMode: String, CaseIterable, Sendable {
    case click, hover
    var title: String { self == .click ? "클릭하면" : "마우스를 올리면" }
}

/// 서랍 닫기 방식
enum CloseMode: String, CaseIterable, Sendable {
    case outsideOrEsc, escOnly
    var title: String { self == .outsideOrEsc ? "바깥 클릭·esc" : "esc만" }
}

/// 서랍·창 색상: 기본(유리) 또는 직접 고른 색
enum DrawerColorMode: String, CaseIterable, Sendable {
    case standard, custom
    var title: String { self == .standard ? "기본" : "색상" }
}

/// 「기본」일 때 서랍만의 밝기 모양(맥 전체 화면 모드는 바꾸지 않음)
enum DrawerAppearance: String, CaseIterable, Sendable {
    case light, dark, system
    var title: String {
        switch self {
        case .light: "라이트"
        case .dark: "다크"
        case .system: "시스템"
        }
    }
}

/// 서랍을 그릴 밝기: true = 다크, false = 라이트, nil = 맥 설정 따름
enum DrawerLook {
    static func isDark(mode: DrawerColorMode, appearance: DrawerAppearance, customHex: String) -> Bool? {
        switch mode {
        case .standard:
            switch appearance {
            case .light: return false
            case .dark: return true
            case .system: return nil
            }
        case .custom:
            // 밝은 바탕이면 라이트(어두운 글자), 어두운 바탕이면 다크(밝은 글자)
            guard let rgb = HexColor.parse(customHex) else { return nil }
            return !HexColor.prefersDarkText(on: rgb)
        }
    }
}
