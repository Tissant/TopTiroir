/// 설정 이름(UserDefaults 키)과 기본값. 화면(@AppStorage)과 동작 코드가 같은 값을 쓰도록 한곳에 모은다.
enum SettingsKey {
    /// 로그인 자동 실행을 마지막으로 등록한 앱 위치(설치 후 다시 등록할지 판단)
    static let loginItemPath = "loginItemPath"
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
    static let notesHeight = "notesHeight"   // v0.2.2부터 모든 탭이 같이 쓰는 서랍 내용 높이
    static let memoRatio = "memoRatio"
    // 화면 켜 두기(마지막 선택만 저장, 켜짐 상태는 저장하지 않음)
    static let keepAwakeMode = "keepAwakeMode"
    static let keepAwakeDuration = "keepAwakeDuration"
    static let keepAwakeUntil = "keepAwakeUntil"
    static let autoStopOnInput = "autoStopOnInput"
    static let autoStopOnBattery = "autoStopOnBattery"
    static let autoStopOnLowBattery = "autoStopOnLowBattery"
    static let autoStopLowBatteryPercent = "autoStopLowBatteryPercent"
    static let indicatorStyle = "indicatorStyle"
    static let indicatorColor = "indicatorColor"
    static let hotKeyCode = "hotKeyCode"
    static let hotKeyModifiers = "hotKeyModifiers"

    /// 서랍 열기 외 단축키(탭 이동·종료): "shortcut.tabNotes" 등
    static func shortcut(_ action: ShortcutAction) -> String { "shortcut." + action.rawValue }
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
    static let memoRatio = Layout.memoRatioDefault
    static let keepAwakeMode = ""          // 처음엔 「선택…」
    static let keepAwakeDuration = KeepAwake.defaultDuration
    static let keepAwakeUntil = -1         // 저장값 없음: 지금 + 1시간을 보여 줌
    static let autoStopOnInput = false
    static let autoStopOnBattery = true
    static let autoStopOnLowBattery = true
    static let autoStopLowBatteryPercent = 20
    static let indicatorStyle = IndicatorStyle.bar.rawValue
    static let indicatorColor = "#F5A623"
    static let hotKeyCode = Int(Shortcut.f12.keyCode)
    static let hotKeyModifiers = Int(Shortcut.f12.modifiers)
}

/// 노치에서 서랍 열기 방식
enum NotchOpenMode: String, CaseIterable, Sendable {
    case click, hover
    var title: String { self == .click ? String(localized: "클릭하면") : String(localized: "마우스를 올리면") }
}

/// 서랍 닫기 방식
enum CloseMode: String, CaseIterable, Sendable {
    case outsideOrEsc, escOnly
    var title: String { self == .outsideOrEsc ? String(localized: "바깥 클릭·esc") : String(localized: "esc만") }
}

/// 서랍·창 색상: 기본(유리) 또는 직접 고른 색
enum DrawerColorMode: String, CaseIterable, Sendable {
    case standard, custom
    var title: String { self == .standard ? String(localized: "기본") : String(localized: "색상") }
}

/// 「기본」일 때 서랍만의 밝기 모양(맥 전체 화면 모드는 바꾸지 않음)
enum DrawerAppearance: String, CaseIterable, Sendable {
    case light, dark, system
    var title: String {
        switch self {
        case .light: String(localized: "라이트")
        case .dark: String(localized: "다크")
        case .system: String(localized: "시스템")
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
