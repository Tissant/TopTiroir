import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let decorations = ScreenDecorations()
    private let hotspot = NotchHotspot()
    private let drawer = DrawerController()
    private let statusItem = TemporaryStatusItem()
    private var hotKey: HotKey?
    private var quickMemoKey: HotKey?
    private let keepAwake = KeepAwakeController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerDefaults()
        migrateSettings()
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

        setUpHotKey()
        drawer.model.keepAwake = keepAwake.model
        keepAwake.closeDrawer = { [weak self] in self?.drawer.close() }
        drawer.model.onDrawerOpened = { [weak self] in self?.keepAwake.refreshForDrawer() }
        // 자동으로 꺼진 이유는 한 번만: 서랍을 닫거나 연 지 5초가 지나면 지운다(DrawerRootView).
        drawer.model.onDrawerClosed = { [weak self] in self?.keepAwake.model.notice = nil }
        drawer.model.onPendingResolved = { [weak self] action, proceed in
            switch action {
            case .close: if proceed { self?.drawer.close() }
            case .quit: NSApp.reply(toApplicationShouldTerminate: proceed)
            }
        }

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(screensChanged),
                           name: NSApplication.didChangeScreenParametersNotification, object: nil)
        center.addObserver(self, selector: #selector(settingsChanged),
                           name: UserDefaults.didChangeNotification, object: nil)

        refreshDecorations()
        LoginItem.reregisterIfMoved()
    }

    /// 앱을 다시 실행하면(Finder·Spotlight) 서랍을 연다. 아이콘이 없는 앱의 비상구.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        drawer.open()
        return false
    }

    /// 할 일을 고치는 중이고 바뀐 내용이 있으면, 서랍의 저장 확인 줄에서 답할 때까지 종료를 미룬다.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if drawer.model.prepareToLeave(.quit) { return .terminateNow }
        drawer.open()
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        drawer.model.favorites.saveNow()
        keepAwake.stop(reason: .stopped)   // 화면 켜 두기 어서션을 꼭 푼다
        drawer.model.notes.saveNow()
        decorations.removeAll()
        statusItem.hide()
    }

    @objc private func screensChanged() {
        refreshDecorations()
        keepAwake.refreshIndicator(force: true)
        drawer.screensChanged()
    }

    @objc private func settingsChanged() {
        refreshDecorations()
        keepAwake.settingsChanged()
        drawer.relayoutIfOpen()
    }

    private func refreshDecorations() {
        decorations.update()
        hotspot.update()
    }

    // MARK: 단축키

    private func setUpHotKey() {
        let defaults = UserDefaults.standard
        let model = drawer.model
        let drawerKey = HotKey(id: 1) { [weak self] in self?.drawer.toggle() }
        let memoKey = HotKey(id: 2) { [weak self] in self?.drawer.quickMemo() }
        hotKey = drawerKey
        quickMemoKey = memoKey
        model.loadShortcuts()
        model.shortcut = Shortcut.stored(keyCode: defaults.integer(forKey: SettingsKey.hotKeyCode),
                                         modifiers: defaults.integer(forKey: SettingsKey.hotKeyModifiers))
        // 빠른 메모 키: 저장값이 있으면 그것, 없으면 기본값(⌃⌥M)
        let memoSaved = defaults.object(forKey: SettingsKey.shortcut(.quickMemo)) != nil
        let memoStored = ShortcutSet.unpack(defaults.integer(forKey: SettingsKey.shortcut(.quickMemo)),
                                            fallback: ShortcutAction.quickMemo.defaultShortcut)
        model.shortcuts[.quickMemo] = memoSaved ? memoStored : ShortcutAction.quickMemo.defaultShortcut
        // 두 키가 같으면(직접 바꾼 값 충돌) 빠른 메모를 기본값으로
        if model.shortcuts[.quickMemo] == model.shortcut { model.shortcuts[.quickMemo] = ShortcutAction.quickMemo.defaultShortcut }
        model.hotKeyAvailable = drawerKey.register(model.shortcut)
        model.quickMemoAvailable = memoKey.register(model.shortcuts[.quickMemo])
        model.onQuickMemo = { [weak self] in self?.drawer.quickMemo() }

        func key(for action: ShortcutAction) -> HotKey { action == .openDrawer ? drawerKey : memoKey }
        func setAvailable(_ action: ShortcutAction, _ ok: Bool) {
            if action == .openDrawer { model.hotKeyAvailable = ok } else { model.quickMemoAvailable = ok }
        }

        // 바꾸는 동안에는 전역 키를 풀어 둬야 그 키도 새 키로 받을 수 있다.
        model.onBeginHotKeyRecording = { drawerKey.unregister(); memoKey.unregister() }
        model.onCancelHotKeyRecording = { [weak model] in
            guard let model else { return }
            model.hotKeyAvailable = drawerKey.register(model.shortcut)
            model.quickMemoAvailable = memoKey.register(model.shortcuts[.quickMemo])
        }
        model.onApplyHotKey = { [weak model] action, new in
            guard let model else { return false }
            let other = action == .openDrawer ? ShortcutAction.quickMemo : .openDrawer
            if key(for: action).register(new) {
                model.shortcuts[action] = new
                setAvailable(action, true)
                if action == .openDrawer {
                    defaults.set(Int(new.keyCode), forKey: SettingsKey.hotKeyCode)
                    defaults.set(Int(new.modifiers), forKey: SettingsKey.hotKeyModifiers)
                } else {
                    defaults.set(ShortcutSet.pack(new), forKey: SettingsKey.shortcut(action))
                }
                // 녹화 시작 때 풀어 둔 다른 전역 키를 다시 등록
                setAvailable(other, key(for: other).register(model.shortcuts[other]))
                return true
            }
            // 실패: 이전 키들을 다시 등록한다.
            setAvailable(action, key(for: action).register(model.shortcuts[action]))
            setAvailable(other, key(for: other).register(model.shortcuts[other]))
            return false
        }
    }

    /// 없어진 켜짐 표시 「노치 손잡이 불빛」을 고른 적이 있으면 막대로 바꿔 둔다.
    private func migrateSettings() {
        let d = UserDefaults.standard
        if let raw = d.string(forKey: SettingsKey.indicatorStyle), IndicatorStyle(rawValue: raw) == nil {
            d.set(IndicatorStyle.resolve(raw).rawValue, forKey: SettingsKey.indicatorStyle)
        }
    }

    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.hideNotch: SettingsDefault.hideNotch,
            SettingsKey.roundCorners: SettingsDefault.roundCorners,
            SettingsKey.bandColor: SettingsDefault.bandColor,
            SettingsKey.drawerScale: SettingsDefault.drawerScale,
            SettingsKey.notchOpenMode: SettingsDefault.notchOpenMode,
            SettingsKey.closeMode: SettingsDefault.closeMode,
            SettingsKey.drawerOpacity: SettingsDefault.drawerOpacity,
            SettingsKey.textScale: SettingsDefault.textScale,
            SettingsKey.textOpacity: SettingsDefault.textOpacity,
            SettingsKey.indentWidth: SettingsDefault.indentWidth,
            SettingsKey.drawerColorMode: SettingsDefault.drawerColorMode,
            SettingsKey.drawerAppearance: SettingsDefault.drawerAppearance,
            SettingsKey.drawerColor: SettingsDefault.drawerColor,
            SettingsKey.openTabMode: SettingsDefault.openTabMode,
            SettingsKey.lastTab: SettingsDefault.lastTab,
            SettingsKey.notesHeight: SettingsDefault.notesHeight,
            SettingsKey.memoRatio: SettingsDefault.memoRatio,
            SettingsKey.keepAwakeMode: SettingsDefault.keepAwakeMode,
            SettingsKey.keepAwakeDuration: SettingsDefault.keepAwakeDuration,
            SettingsKey.keepAwakeUntil: SettingsDefault.keepAwakeUntil,
            SettingsKey.autoStopOnInput: SettingsDefault.autoStopOnInput,
            SettingsKey.autoStopOnBattery: SettingsDefault.autoStopOnBattery,
            SettingsKey.autoStopOnLowBattery: SettingsDefault.autoStopOnLowBattery,
            SettingsKey.autoStopLowBatteryPercent: SettingsDefault.autoStopLowBatteryPercent,
            SettingsKey.indicatorStyle: SettingsDefault.indicatorStyle,
            SettingsKey.indicatorColor: SettingsDefault.indicatorColor,
            SettingsKey.hotKeyCode: SettingsDefault.hotKeyCode,
            SettingsKey.hotKeyModifiers: SettingsDefault.hotKeyModifiers,
        ])
    }
}
