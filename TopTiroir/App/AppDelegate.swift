import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let decorations = ScreenDecorations()
    private let hotspot = NotchHotspot()
    private let drawer = DrawerController()
    private let statusItem = TemporaryStatusItem()
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerDefaults()
        DrawerController.shared = drawer

        drawer.model.onShowStatusItem = { [weak self] in self?.statusItem.show() }
        statusItem.onClick = { [weak self] in self?.drawer.toggle() }
        hotspot.onClick = { [weak self] in self?.drawer.toggle(on: NSScreen.ttBuiltInNotch) }
        hotspot.onHover = { [weak self] in
            guard let self else { return }
            let mode = UserDefaults.standard.string(forKey: SettingsKey.notchOpenMode)
            if mode == NotchOpenMode.hover.rawValue, !drawer.isOpen {
                drawer.open(on: NSScreen.ttBuiltInNotch)
            }
        }

        let key = HotKey(keyCode: HotKey.f12) { [weak self] in self?.drawer.toggle() }
        drawer.model.hotKeyAvailable = key.register()
        hotKey = key

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(screensChanged),
                           name: NSApplication.didChangeScreenParametersNotification, object: nil)
        center.addObserver(self, selector: #selector(settingsChanged),
                           name: UserDefaults.didChangeNotification, object: nil)

        refreshDecorations()
    }

    /// 앱을 다시 실행하면(Finder·Spotlight) 서랍을 연다. 아이콘이 없는 앱의 비상구.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        drawer.open()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        decorations.removeAll()
        statusItem.hide()
    }

    @objc private func screensChanged() {
        refreshDecorations()
        drawer.screensChanged()
    }

    @objc private func settingsChanged() {
        refreshDecorations()
        drawer.relayoutIfOpen()
    }

    private func refreshDecorations() {
        decorations.update()
        hotspot.update()
    }

    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.hideNotch: SettingsDefault.hideNotch,
            SettingsKey.roundCorners: SettingsDefault.roundCorners,
            SettingsKey.bandColor: SettingsDefault.bandColor,
            SettingsKey.drawerScale: SettingsDefault.drawerScale,
            SettingsKey.notchOpenMode: SettingsDefault.notchOpenMode,
            SettingsKey.closeMode: SettingsDefault.closeMode,
        ])
    }
}
