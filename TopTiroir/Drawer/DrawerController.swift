import AppKit
import Observation
import SwiftUI

/// 서랍 화면과 AppKit 쪽이 함께 보는 상태
@MainActor
@Observable
final class DrawerModel {
    var tab: DrawerTab = .notes {
        didSet {
            guard tab != oldValue else { return }
            UserDefaults.standard.set(tab.rawValue, forKey: SettingsKey.lastTab)
        }
    }
    var maxHeight: CGFloat = 500
    /// 서랍을 열 때마다 1씩 늘어난다(펼친 목록·확인 줄을 접는 신호).
    var openCount = 0
    var contentHeight: CGFloat = 320
    /// 메모/할 일 영역 높이(끌어서 바꿈). 끄는 동안엔 화면에만, 손을 떼면 저장.
    var notesHeight: CGFloat = Layout.notesDefaultHeight

    let notes = NotesStore()

    // 할 일 고치기
    struct TodoEdit: Equatable {
        var id: UUID
        var draft: String
    }
    enum PendingAction { case close, quit }
    var todoEdit: TodoEdit?
    /// 고친 내용이 있는데 닫기·종료하려 할 때: 저장 확인 줄을 보이는 동안 미뤄 둔 일
    var pendingAction: PendingAction?
    @ObservationIgnored var onPendingResolved: ((PendingAction, Bool) -> Void)?

    // 단축키
    var shortcuts = ShortcutSet.defaults
    var hotKeyAvailable = true
    /// 지금 「새 키를 누르세요」 상태인 항목
    var recordingAction: ShortcutAction?
    /// 항목별 안내(충돌·실패 등)
    var shortcutMessage: (action: ShortcutAction, text: String)?
    /// 단축키 보기 창이 열려 있는지
    var shortcutsWindowOpen = false
    @ObservationIgnored var onToggleShortcutsWindow: (() -> Void)?

    /// 서랍 열기 단축키(설정 탭의 줄과 단축키 창이 같은 값을 쓴다)
    var shortcut: Shortcut {
        get { shortcuts[.openDrawer] }
        set { shortcuts[.openDrawer] = newValue }
    }
    var isRecordingHotKey: Bool { recordingAction == .openDrawer }
    var hotKeyMessage: String? { shortcutMessage?.action == .openDrawer ? shortcutMessage?.text : nil }

    @ObservationIgnored var onLayoutChange: (() -> Void)?
    @ObservationIgnored var onShowStatusItem: (() -> Void)?
    /// 색상 창 열기: (저장할 설정 이름, 기본값)
    @ObservationIgnored var onShowColorPanel: ((String, String) -> Void)?
    /// 투명도 슬라이드바를 끄는 동안 미리 보기 값(손을 떼면 nil)
    var windowOpacityPreview: Double?
    var textOpacityPreview: Double?
    /// 단축키 바꾸기: 시작(현재 키 잠시 해제) / 적용(성공하면 true) / 취소(현재 키 다시 등록)
    @ObservationIgnored var onBeginHotKeyRecording: (() -> Void)?
    @ObservationIgnored var onApplyHotKey: ((Shortcut) -> Bool)?
    @ObservationIgnored var onCancelHotKeyRecording: (() -> Void)?

    var hasUnsavedTodoEdit: Bool {
        guard let e = todoEdit, let item = notes.document.todos.first(where: { $0.id == e.id }) else { return false }
        return NotesDocument.isEditChanged(original: item.text, draft: e.draft)
    }

    func beginTodoEdit(_ item: TodoItem) {
        if todoEdit != nil { commitTodoEdit() }
        todoEdit = TodoEdit(id: item.id, draft: item.text)
    }

    /// 엔터: 저장하고 끝내기(빈 글이면 원래 글 유지)
    func commitTodoEdit() {
        if let e = todoEdit { notes.updateTodo(e.id, text: e.draft) }
        todoEdit = nil
        pendingAction = nil
    }

    /// esc: 원래 글로 되돌리고 끝내기
    func cancelTodoEdit() {
        todoEdit = nil
        pendingAction = nil
    }

    /// 닫기·종료 전에 부른다. 바로 진행해도 되면 true, 저장 확인 줄을 띄웠으면 false.
    func prepareToLeave(_ action: PendingAction) -> Bool {
        guard todoEdit != nil else { return true }
        if hasUnsavedTodoEdit {
            pendingAction = action
            return false
        }
        todoEdit = nil
        return true
    }

    /// 저장 확인 줄의 답: true 저장, false 저장 안 함, nil 취소(수정 모드 유지)
    func resolvePending(save: Bool?) {
        guard let action = pendingAction else { return }
        pendingAction = nil
        guard let save else {
            onPendingResolved?(action, false)
            return
        }
        if save, let e = todoEdit { notes.updateTodo(e.id, text: e.draft) }
        todoEdit = nil
        onPendingResolved?(action, true)
    }

    func reportContentHeight(_ height: CGFloat) {
        guard abs(height - contentHeight) > 0.5 else { return }
        contentHeight = height
        onLayoutChange?()
    }

    func setNotesHeight(_ height: CGFloat, save: Bool) {
        if abs(height - notesHeight) > 0.5 {
            notesHeight = height
            onLayoutChange?()
        }
        if save { UserDefaults.standard.set(Double(height), forKey: SettingsKey.notesHeight) }
    }

    // MARK: 단축키 바꾸기

    func beginRecording(_ action: ShortcutAction) {
        if let current = recordingAction {
            if current == action { finishRecording(nil); return }   // 같은 줄을 다시 누르면 취소
            finishRecording(nil)
        }
        shortcutMessage = nil
        recordingAction = action
        // 어떤 키를 녹화하든 전역 단축키를 잠시 풀어 둔다(F12 등을 누르면 서랍이 닫혀 버리지 않게).
        onBeginHotKeyRecording?()
    }

    /// 누른 키(nil이면 취소)
    func finishRecording(_ new: Shortcut?) {
        guard let action = recordingAction else { return }
        recordingAction = nil
        if let new, action == .openDrawer {
            assign(new, to: action)          // 새 키로 전역 등록(실패하면 이전 키로)
        } else {
            onCancelHotKeyRecording?()       // 지금 서랍 열기 키를 다시 등록
            if let new { assign(new, to: action) }
        }
    }

    /// 녹화 중 누른 키 검사. 문제가 있으면 안내만 띄우고 계속 기다린다.
    func handleRecordedKey(_ s: Shortcut) {
        guard let action = recordingAction else { return }
        switch shortcuts.check(s, for: action) {
        case .ok: finishRecording(s)
        case .cancel: finishRecording(nil)
        case .needsModifier: say(action, "글자·숫자 키는 ⌘ 또는 ⌃와 함께 눌러 주세요. (F1~F20은 혼자 써도 돼요)")
        case .needsCommand: say(action, "종료는 ⌘와 함께 눌러 주세요.")
        case .unsupported: say(action, "이 키는 쓸 수 없어요. 다른 키를 눌러 주세요.")
        case .conflict(let owner): say(action, "\(s.normalized.displayName)은(는) 「\(owner)」에서 이미 쓰는 키예요. 다른 키를 눌러 주세요.")
        }
    }

    func reset(_ action: ShortcutAction) {
        if recordingAction != nil { finishRecording(nil) }
        let d = action.defaultShortcut
        if case .conflict(let owner) = shortcuts.check(d, for: action) {
            say(action, "기본값 \(d.displayName)을(를) 「\(owner)」에서 쓰고 있어요. 그쪽을 먼저 바꿔 주세요.")
            return
        }
        assign(d, to: action)
    }

    func resetAll() {
        if recordingAction != nil { finishRecording(nil) }
        shortcutMessage = nil
        for action in ShortcutAction.allCases where action != .openDrawer {
            shortcuts[action] = action.defaultShortcut
            save(action)
        }
        assign(.f12, to: .openDrawer)
    }

    // 예전 이름(설정 탭의 서랍 열기 줄)
    func beginHotKeyRecording() { beginRecording(.openDrawer) }
    func finishHotKeyRecording(_ new: Shortcut?) { if recordingAction == .openDrawer { finishRecording(new) } }
    func resetHotKey() { reset(.openDrawer) }

    private func assign(_ new: Shortcut, to action: ShortcutAction) {
        if action == .openDrawer {
            let old = shortcut
            if onApplyHotKey?(new) == true {
                if shortcutMessage?.action == action { shortcutMessage = nil }
            } else {
                say(action, "\(new.displayName)은(는) 다른 앱에서 쓰고 있어 바꾸지 못했어요. \(old.displayName)을(를) 그대로 써요.")
            }
            return
        }
        shortcuts[action] = new
        save(action)
        if shortcutMessage?.action == action { shortcutMessage = nil }
    }

    private func save(_ action: ShortcutAction) {
        guard action != .openDrawer else { return } // 서랍 열기는 AppDelegate가 저장(전역 등록 성공 때만)
        UserDefaults.standard.set(ShortcutSet.pack(shortcuts[action]), forKey: SettingsKey.shortcut(action))
    }

    private func say(_ action: ShortcutAction, _ text: String) {
        shortcutMessage = (action, text)
    }

    /// 저장된 값 불러오기(서랍 열기는 AppDelegate가 따로)
    func loadShortcuts() {
        let d = UserDefaults.standard
        for action in ShortcutAction.allCases where action != .openDrawer {
            if d.object(forKey: SettingsKey.shortcut(action)) != nil {
                shortcuts[action] = ShortcutSet.unpack(d.integer(forKey: SettingsKey.shortcut(action)),
                                                       fallback: action.defaultShortcut)
            }
        }
    }
}

/// 서랍 열기·닫기·위치 맞추기
@MainActor
final class DrawerController {
    let model = DrawerModel()

    private let panel = DrawerPanel()
    private let hosting: NSHostingView<DrawerRootView>
    private var screen: NSScreen?
    private var globalMouseMonitor: Any?
    private var localKeyMonitor: Any?
    private var localMouseMonitor: Any?
    private let shortcutsPanel = DrawerPanel()
    private let shortcutsHosting: NSHostingView<ShortcutsView>

    var isOpen: Bool { panel.isVisible }

    init() {
        hosting = NSHostingView(rootView: DrawerRootView(model: model))
        hosting.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hosting
        shortcutsHosting = NSHostingView(rootView: ShortcutsView(model: model))
        shortcutsHosting.sizingOptions = []
        shortcutsPanel.contentView = shortcutsHosting
        shortcutsPanel.level = NSWindow.Level(rawValue: panel.level.rawValue + 1)
        model.onToggleShortcutsWindow = { [weak self] in self?.toggleShortcutsWindow() }
        model.onLayoutChange = { [weak self] in
            DispatchQueue.main.async { self?.relayoutIfOpen() }
        }
        model.onShowColorPanel = { [weak self] key, fallback in
            guard let self else { return }
            BandColorPanel.shared.show(key: key, fallback: fallback, nextTo: panel.frame, above: panel.level)
        }
    }

    func toggle(on screen: NSScreen? = nil) {
        isOpen ? close() : open(on: screen)
    }

    func open(on target: NSScreen? = nil) {
        guard let s = target ?? NSScreen.ttUnderMouse else { return }
        let defaults = UserDefaults.standard
        if !isOpen {
            let mode = OpenTabMode(rawValue: defaults.string(forKey: SettingsKey.openTabMode) ?? "") ?? .last
            model.tab = mode.tab(lastTab: defaults.string(forKey: SettingsKey.lastTab))
            model.notesHeight = CGFloat(defaults.double(forKey: SettingsKey.notesHeight))
        }
        screen = s
        model.maxHeight = Layout.maxDrawerHeight(screenFrame: s.frame)
        relayout()
        let wasOpen = isOpen
        panel.orderFrontRegardless()
        panel.makeKey()
        // 열 때 아무 칸에도 글자 커서를 두지 않는다(들여쓰기 칸 등에 자동으로 커서가 가서 타자가 들어가지 않게).
        if !wasOpen {
            panel.makeFirstResponder(nil)
            model.openCount += 1
        }
        installMonitors()
    }

    func close() {
        guard isOpen else { return }
        // 할 일을 고치는 중이고 바뀐 내용이 있으면 닫지 않고 저장 확인 줄을 보인다.
        guard model.prepareToLeave(.close) else { return }
        model.finishRecording(nil)
        panel.orderOut(nil)
        hideShortcutsWindow()
        BandColorPanel.shared.close()
        removeMonitors()
        model.notes.saveNow()
    }

    func relayoutIfOpen() {
        if isOpen { relayout() }
    }

    /// 화면 구성이 바뀌면 같은 자리에 맞춘다(사라진 화면이면 닫는다).
    func screensChanged() {
        guard isOpen else { return }
        if let s = screen, NSScreen.screens.contains(s) {
            open(on: s)
        } else {
            close()
        }
    }

    private func relayout() {
        guard let s = screen else { return }
        let scale = UserDefaults.standard.double(forKey: SettingsKey.drawerScale)
        hosting.layoutSubtreeIfNeeded()
        let frame = Layout.drawerFrame(screenFrame: s.frame, menuBarHeight: s.ttMenuBarHeight,
                                       contentHeight: hosting.fittingSize.height, scale: scale)
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        applyAppearance()
        panel.invalidateShadow()
        if model.shortcutsWindowOpen { placeShortcutsWindow() }
    }

    // MARK: 단축키 보기 창 (서랍 옆)

    private func toggleShortcutsWindow() {
        if model.shortcutsWindowOpen { hideShortcutsWindow() } else { showShortcutsWindow() }
    }

    private func showShortcutsWindow() {
        guard isOpen else { return }
        model.shortcutsWindowOpen = true
        placeShortcutsWindow()
        shortcutsPanel.orderFrontRegardless()
    }

    private func hideShortcutsWindow() {
        if model.recordingAction != nil { model.finishRecording(nil) }
        model.shortcutsWindowOpen = false
        shortcutsPanel.orderOut(nil)
    }

    /// 서랍 오른쪽에 서랍과 같은 높이로. 화면 밖으로 나가면 서랍 왼쪽에.
    private func placeShortcutsWindow() {
        guard let s = screen else { return }
        let d = UserDefaults.standard
        let width = Layout.shortcutsWindowWidth(scale: d.double(forKey: SettingsKey.drawerScale))
        let frame = Layout.sideWindowFrame(drawer: panel.frame, width: width, gap: 8, screenFrame: s.frame)
        if shortcutsPanel.frame != frame { shortcutsPanel.setFrame(frame, display: true) }
        shortcutsPanel.appearance = panel.appearance
        shortcutsPanel.invalidateShadow()
    }

    /// 서랍만의 밝기 모양(맥 전체 화면 모드는 그대로). 직접 고른 색이면 그 밝기에 맞춰 글자색이 정해진다.
    private func applyAppearance() {
        let d = UserDefaults.standard
        let dark = DrawerLook.isDark(
            mode: DrawerColorMode(rawValue: d.string(forKey: SettingsKey.drawerColorMode) ?? "") ?? .standard,
            appearance: DrawerAppearance(rawValue: d.string(forKey: SettingsKey.drawerAppearance) ?? "") ?? .system,
            customHex: d.string(forKey: SettingsKey.drawerColor) ?? SettingsDefault.drawerColor)
        let wanted: NSAppearance? = dark.map { NSAppearance(named: $0 ? .darkAqua : .aqua)! }
        if panel.appearance?.name != wanted?.name { panel.appearance = wanted }
    }

    // MARK: 닫기 감시 (바깥 클릭, esc)

    private func installMonitors() {
        removeMonitors()
        // 다른 앱 화면을 클릭했을 때만 불린다(이 앱의 창 클릭은 해당 없음). 마우스 감시는 권한이 필요 없다.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            MainActor.assumeIsolated {
                let mode = UserDefaults.standard.string(forKey: SettingsKey.closeMode)
                if mode != CloseMode.escOnly.rawValue { DrawerController.shared?.close() }
            }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            MainActor.assumeIsolated {
                if event.window === DrawerController.shared?.panel { DrawerController.resignTextFocusIfNeeded(event) }
            }
            return event
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // 단축키 바꾸는 중이면 누른 키를 모두 여기서 받는다(esc는 취소).
            let recorded = MainActor.assumeIsolated { () -> Bool in
                guard let model = DrawerController.shared?.model, model.recordingAction != nil else { return false }
                model.handleRecordedKey(Shortcut(keyCode: UInt32(event.keyCode),
                                                 modifiers: DrawerController.carbonModifiers(event.modifierFlags)))
                return true
            }
            if recorded { return nil }
            // 편집 단축키: 이 앱은 메뉴막대(편집 메뉴)가 없어 ⌘Z·⌘C 같은 키가 입력칸까지 가지 않는다.
            // 그래서 여기서 지금 글자 커서가 있는 칸(첫 응답자)에 편집 명령을 직접 보낸다.
            if let action = DrawerController.editAction(for: event) {
                let handled = MainActor.assumeIsolated { () -> Bool in
                    DrawerController.commitMarkedText(in: event.window)
                    return NSApp.sendAction(action, to: nil, from: nil)
                }
                if handled { return nil }
            }
            // 종료(기본 ⌘Q)·탭 이동(기본 1·2·3). 탭 이동은 글자 커서가 없을 때만(입력칸이면 숫자가 글자로).
            let local = MainActor.assumeIsolated { () -> Bool in
                guard let model = DrawerController.shared?.model else { return false }
                let focused = DrawerController.isTextInput(event.window?.firstResponder)
                switch model.shortcuts.localAction(keyCode: event.keyCode,
                                                   modifiers: DrawerController.carbonModifiers(event.modifierFlags),
                                                   textFocused: focused) {
                case .quit:
                    NSApp.terminate(nil)   // 저장 확인은 applicationShouldTerminate에서
                    return true
                case .showTab(let tab):
                    model.tab = tab
                    return true
                case nil:
                    return false
                }
            }
            if local { return nil }
            if event.keyCode == 53 { // esc
                // 할 일을 고치는 중이면 esc는 고치기 취소(서랍은 그대로)
                let cancelledEdit = MainActor.assumeIsolated { () -> Bool in
                    guard let model = DrawerController.shared?.model, model.todoEdit != nil else { return false }
                    if model.pendingAction == nil { model.cancelTodoEdit() } else { model.resolvePending(save: nil) }
                    return true
                }
                if cancelledEdit { return nil }
                MainActor.assumeIsolated { DrawerController.shared?.close() }
                return nil
            }
            return event
        }
    }

    private func removeMonitors() {
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m) }
        if let m = localKeyMonitor { NSEvent.removeMonitor(m) }
        if let m = localMouseMonitor { NSEvent.removeMonitor(m) }
        globalMouseMonitor = nil
        localKeyMonitor = nil
        localMouseMonitor = nil
    }

    /// 글자 커서가 있는 칸인지(메모 칸, 입력칸의 필드 편집기는 모두 NSTextView)
    private static func isTextInput(_ responder: NSResponder?) -> Bool {
        responder is NSTextView
    }

    /// 서랍에서 입력칸이 아닌 곳을 누르면 글자 커서를 뺀다(그래야 1·2·3 탭 이동이 동작).
    private static func resignTextFocusIfNeeded(_ event: NSEvent) {
        guard let window = event.window, isTextInput(window.firstResponder),
              let content = window.contentView else { return }
        var view = content.hitTest(content.convert(event.locationInWindow, from: nil))
        while let v = view {
            if v is NSTextView || v is NSTextField { return }   // 입력칸을 누른 것
            view = v.superview
        }
        DispatchQueue.main.async { window.makeFirstResponder(nil) }
    }

    /// ⌘Z 되돌리기 · ⇧⌘Z 다시 실행 · ⌘X 잘라내기 · ⌘C 복사 · ⌘V 붙여넣기 · ⌘A 전체 선택
    /// 키 위치(키 코드)로 편집 명령을 고른다(한글 입력 중에도 동작). 계산은 Core의 EditCommand.
    nonisolated private static func editAction(for event: NSEvent) -> Selector? {
        let f = event.modifierFlags
        return EditCommand.from(keyCode: event.keyCode, command: f.contains(.command), shift: f.contains(.shift),
                                option: f.contains(.option), control: f.contains(.control))
            .map { Selector($0.selectorName) }
    }

    /// 한글 조합 중(밑줄 글자)이면 먼저 확정해서, 명령이 조합 중인 글자를 깨뜨리지 않게 한다.
    private static func commitMarkedText(in window: NSWindow?) {
        // 서랍은 앱을 활성으로 만들지 않아 NSApp.keyWindow가 비어 있을 수 있어, 키를 받은 창을 쓴다.
        if let tv = window?.firstResponder as? NSTextView, tv.hasMarkedText() {
            tv.unmarkText()
        }
    }

    fileprivate static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= Shortcut.Modifier.command }
        if flags.contains(.shift) { m |= Shortcut.Modifier.shift }
        if flags.contains(.option) { m |= Shortcut.Modifier.option }
        if flags.contains(.control) { m |= Shortcut.Modifier.control }
        return m
    }

    /// 감시 함수(@Sendable)에서 self를 잡지 않으려고 쓰는 하나뿐인 서랍
    static weak var shared: DrawerController?
}

/// 유리 서랍 창: 테두리 없음, 다른 앱을 비활성으로 만들지 않음, 키 입력(esc) 받기 가능
final class DrawerPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
