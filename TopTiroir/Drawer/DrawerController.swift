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
    var shortcut: Shortcut = .f12
    var hotKeyAvailable = true
    var isRecordingHotKey = false
    var hotKeyMessage: String?

    @ObservationIgnored var onLayoutChange: (() -> Void)?
    @ObservationIgnored var onShowStatusItem: (() -> Void)?
    @ObservationIgnored var onShowColorPanel: (() -> Void)?
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

    func beginHotKeyRecording() {
        guard !isRecordingHotKey else { return }
        hotKeyMessage = nil
        isRecordingHotKey = true
        onBeginHotKeyRecording?()
    }

    /// nil이면 취소
    func finishHotKeyRecording(_ new: Shortcut?) {
        guard isRecordingHotKey else { return }
        isRecordingHotKey = false
        if let new { applyHotKey(new) } else { onCancelHotKeyRecording?() }
    }

    func resetHotKey() {
        if isRecordingHotKey { isRecordingHotKey = false }
        applyHotKey(.f12)
    }

    private func applyHotKey(_ new: Shortcut) {
        let old = shortcut
        if onApplyHotKey?(new) == true {
            hotKeyMessage = nil
        } else {
            hotKeyMessage = "\(new.displayName)은(는) 다른 곳에서 쓰고 있어 바꾸지 못했어요. \(old.displayName)을(를) 그대로 써요."
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

    var isOpen: Bool { panel.isVisible }

    init() {
        hosting = NSHostingView(rootView: DrawerRootView(model: model))
        hosting.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hosting
        model.onLayoutChange = { [weak self] in
            DispatchQueue.main.async { self?.relayoutIfOpen() }
        }
        model.onShowColorPanel = { [weak self] in
            guard let self else { return }
            BandColorPanel.shared.show(nextTo: panel.frame, above: panel.level)
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
        panel.orderFrontRegardless()
        panel.makeKey()
        installMonitors()
    }

    func close() {
        guard isOpen else { return }
        // 할 일을 고치는 중이고 바뀐 내용이 있으면 닫지 않고 저장 확인 줄을 보인다.
        guard model.prepareToLeave(.close) else { return }
        model.finishHotKeyRecording(nil)
        panel.orderOut(nil)
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
        panel.invalidateShadow()
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
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // 단축키 바꾸는 중이면 누른 키를 모두 여기서 받는다(esc는 취소).
            let recorded = MainActor.assumeIsolated { () -> Bool in
                guard let model = DrawerController.shared?.model, model.isRecordingHotKey else { return false }
                DrawerController.record(event, into: model)
                return true
            }
            if recorded { return nil }
            // ⌘Q: 어느 탭에서든 종료(저장 확인은 applicationShouldTerminate에서)
            if event.keyCode == 12, event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
                MainActor.assumeIsolated { NSApp.terminate(nil) }
                return nil
            }
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
        globalMouseMonitor = nil
        localKeyMonitor = nil
    }

    private static func record(_ event: NSEvent, into model: DrawerModel) {
        let keyCode = UInt32(event.keyCode)
        let mods = carbonModifiers(event.modifierFlags)
        switch Shortcut.check(keyCode: keyCode, modifiers: mods) {
        case .ok: model.finishHotKeyRecording(Shortcut(keyCode: keyCode, modifiers: mods))
        case .cancel: model.finishHotKeyRecording(nil)
        case .needsModifier: model.hotKeyMessage = "글자·숫자 키는 ⌘ 또는 ⌃와 함께 눌러 주세요. (F1~F20은 혼자 써도 돼요)"
        case .unsupported: model.hotKeyMessage = "이 키는 쓸 수 없어요. 다른 키를 눌러 주세요."
        }
    }

    private static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
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
