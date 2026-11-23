import AppKit

// Dock·메뉴막대 아이콘이 없는 앱(LSUIElement). 창은 코드로 직접 띄운다.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
