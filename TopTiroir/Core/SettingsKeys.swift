/// 설정 이름(UserDefaults 키)과 기본값. 화면(@AppStorage)과 동작 코드가 같은 값을 쓰도록 한곳에 모은다.
enum SettingsKey {
    static let hideNotch = "hideNotch"
    static let roundCorners = "roundCorners"
    static let bandColor = "bandColor"
    static let drawerScale = "drawerScale"
    static let notchOpenMode = "notchOpenMode"
    static let closeMode = "closeMode"
}

enum SettingsDefault {
    static let hideNotch = true
    static let roundCorners = false
    static let bandColor = "#0B0C10"
    static let drawerScale = 1.0
    static let notchOpenMode = NotchOpenMode.click.rawValue
    static let closeMode = CloseMode.outsideOrEsc.rawValue
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
