import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// 서랍 화면과 AppKit 쪽이 함께 보는 상태
@MainActor
@Observable
final class DrawerModel {
    var tab: DrawerTab = .notes {
        didSet {
            guard tab != oldValue else { return }
            UserDefaults.standard.set(tab.rawValue, forKey: SettingsKey.lastTab)
            onTabChanged?(tab)
        }
    }
    /// 탭이 바뀌면(책갈피·단축키 모두) 불린다: 설정 탭에서 연 보조 창(단축키·색상)을 닫는 데 쓴다.
    @ObservationIgnored var onTabChanged: ((DrawerTab) -> Void)?
    /// 메모 몫(메모/할 일 사이 손잡이)
    var memoRatio: Double = Layout.memoRatioDefault
    var maxHeight: CGFloat = 500
    /// 서랍을 열 때마다 1씩 늘어난다(펼친 목록·확인 줄을 접는 신호).
    var openCount = 0
    /// 서랍이 지금 열려 있는지(안내 5초 타이머용)
    var isDrawerOpen = false
    var contentHeight: CGFloat = 320
    /// 메모/할 일 영역 높이(끌어서 바꿈). 끄는 동안엔 화면에만, 손을 떼면 저장.
    var notesHeight: CGFloat = Layout.notesDefaultHeight

    let notes = NotesStore()
    let favorites = FavoritesStore()
    /// 열린 목록 창들(묶음 id, 최대 3칸)
    var columnStack: [UUID] = [] {
        didSet { if columnStack != oldValue { onColumnsChanged?() } }
    }
    @ObservationIgnored var onColumnsChanged: (() -> Void)?
    /// 즐겨찾기 수정 모드: 바깥을 눌러도 서랍이 닫히지 않는다(Finder에서 끌어다 놓기). 「저장」·서랍 닫기·탭 이동으로 끝.
    var favoritesEditing = false {
        didSet {
            if !favoritesEditing && oldValue { favorites.saveNow() }
            if favoritesEditing != oldValue { onColumnsChanged?() }   // 폴더 창 폭 다시 계산
        }
    }
    /// 진단 기록용: 마우스가 올라가 있는 즐겨찾기 줄 종류
    @ObservationIgnored var hoveredFavoriteKind: String?
    /// 목록 창 칸마다 내용 높이(입력 줄 포함)
    @ObservationIgnored private(set) var columnContentHeights: [Int: CGFloat] = [:]

    func reportColumnHeight(_ level: Int, fixed: CGFloat, items: CGFloat) {
        let total = Layout.listWindowHeight(fixed: fixed, items: items)
        guard abs((columnContentHeights[level] ?? 0) - total) > 0.5 else { return }
        columnContentHeights[level] = total
        onColumnsChanged?()
    }
    /// 「앱·파일·폴더 선택…」: 그 목록(path)에 넣을 파일 고르기 창
    @ObservationIgnored var onChooseFiles: (([UUID]) -> Void)?
    /// 앱·파일·폴더·웹 주소를 열었을 때(서랍 닫기)
    @ObservationIgnored var onFavoriteOpened: (() -> Void)?

    /// 즐겨찾기 줄을 누름: 묶음이면 목록 창을 열고 닫고, 나머지는 열고 서랍을 닫는다.
    func tapFavorite(_ item: FavoriteItem, level: Int) {
        // 수정 중에는 앱·파일·웹 주소를 열지 않는다(실수 방지). 폴더 창은 열고 닫는다.
        if favoritesEditing && item.kind != .group { return }
        favorites.noticeLevel = level
        // 서랍은 열기가 끝난 뒤에 닫는다(먼저 닫으면 활성 넘겨주기를 방해할 수 있음).
        let action = favorites.activate(item) { [weak self] in
            self?.onFavoriteOpened?()   // 바로 닫지 않고 「실행 후 유지」(마우스가 나가면 닫힘)
        }
        if action == .toggleGroup {
            columnStack = FavoriteColumns.toggle(item.id, fromLevel: level, stack: columnStack)
        }
    }
    // MARK: 내보내기·가져오기 (설정 › 관리)

    /// 「내보내기…」: 저장 창 띄우기
    @ObservationIgnored var onExportBackup: (() -> Void)?
    /// 「가져오기…」: 고르기 창 띄우기 → 읽으면 pendingImport에 넣고 설정 탭에서 확인
    @ObservationIgnored var onImportBackup: (() -> Void)?
    /// 고른 백업 파일(확인 줄을 보이는 동안)
    var pendingImport: BackupFile?
    /// 내보내기·가져오기 결과 한 줄
    var backupMessage: String?

    /// 지금 내용을 백업 파일로
    func makeBackup() -> BackupFile {
        notes.saveNow()
        favorites.saveNow()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        return BackupFile(exportedAt: Date(), appVersion: version,
                          notes: notes.document, favorites: favorites.document)
    }

    /// 확인 줄에서 「가져오기」: 고른 부분만 바꾼다(각각 바꾸기 직전 상태를 백업 파일로 남김).
    func applyImport(notes takeNotes: Bool, favorites takeFavorites: Bool) {
        guard let file = pendingImport else { return }
        pendingImport = nil
        var done: [String] = [], failed: [String] = []
        if takeNotes, let n = file.notes {
            todoEdit = nil
            if notes.replace(with: n) { done.append(String(localized: "메모·할 일")) } else { failed.append(String(localized: "메모·할 일")) }
        }
        if takeFavorites, let f = file.favorites {
            favoritesEditing = false
            columnStack = []
            if favorites.replace(with: f) { done.append(String(localized: "즐겨찾기")) } else { failed.append(String(localized: "즐겨찾기")) }
        }
        if !failed.isEmpty {
            backupMessage = String(localized: "\(failed.joined(separator: "·"))는 지금 내용을 백업하지 못해 바꾸지 않았어요.")
        } else if done.isEmpty {
            backupMessage = String(localized: "아무것도 가져오지 않았어요.")
        } else {
            backupMessage = String(localized: "\(done.joined(separator: "·"))를 가져왔어요. 바꾸기 전 내용은 백업 파일로 남겼어요.")
        }
    }

    /// 화면 켜 두기(AppDelegate가 KeepAwakeController의 모델로 바꿔 끼운다)
    var keepAwake = KeepAwakeModel()
    @ObservationIgnored var onDrawerOpened: (() -> Void)?
    @ObservationIgnored var onDrawerClosed: (() -> Void)?

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
    /// 빠른 메모 전역 키가 등록됐는지(다른 앱이 쓰면 false)
    var quickMemoAvailable = true
    /// 올라가면 메모 칸에 글자 커서를 둔다(MemoTextView가 값 변화를 본다)
    var memoFocusRequest = 0
    @ObservationIgnored var onQuickMemo: (() -> Void)?
    /// 지금 「새 키를 누르세요」 상태인 항목
    var recordingAction: ShortcutAction?
    /// 항목별 안내(충돌·실패 등)
    var shortcutMessage: (action: ShortcutAction, text: String)?
    /// 단축키 보기 창이 열려 있는지
    var shortcutsWindowOpen = false
    @ObservationIgnored var onToggleShortcutsWindow: (() -> Void)?

    /// 서랍 열기 단축키(단축키 창에서 바꾼다)
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
    @ObservationIgnored var onApplyHotKey: ((ShortcutAction, Shortcut) -> Bool)?
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
        if let new, action.isGlobal {
            assign(new, to: action)          // 새 키로 전역 등록(실패하면 이전 키로)
        } else {
            onCancelHotKeyRecording?()       // 전역 키(서랍 열기·빠른 메모)를 다시 등록
            if let new { assign(new, to: action) }
        }
    }

    /// 녹화 중 누른 키 검사. 문제가 있으면 안내만 띄우고 계속 기다린다.
    func handleRecordedKey(_ s: Shortcut) {
        guard let action = recordingAction else { return }
        switch shortcuts.check(s, for: action) {
        case .ok: finishRecording(s)
        case .cancel: finishRecording(nil)
        case .needsModifier: say(action, String(localized: "글자·숫자 키는 ⌘ 또는 ⌃와 함께 눌러 주세요. (F1~F20은 혼자 써도 돼요)"))
        case .needsCommand: say(action, String(localized: "종료는 ⌘와 함께 눌러 주세요."))
        case .unsupported: say(action, String(localized: "이 키는 쓸 수 없어요. 다른 키를 눌러 주세요."))
        case .conflict(let owner): say(action, String(localized: "\(s.normalized.displayName)은(는) 「\(owner)」에서 이미 쓰는 키예요. 다른 키를 눌러 주세요."))
        }
    }

    func reset(_ action: ShortcutAction) {
        if recordingAction != nil { finishRecording(nil) }
        let d = action.defaultShortcut
        if case .conflict(let owner) = shortcuts.check(d, for: action) {
            say(action, String(localized: "기본값 \(d.displayName)을(를) 「\(owner)」에서 쓰고 있어요. 그쪽을 먼저 바꿔 주세요."))
            return
        }
        assign(d, to: action)
    }

    func resetAll() {
        if recordingAction != nil { finishRecording(nil) }
        shortcutMessage = nil
        for action in ShortcutAction.allCases where !action.isGlobal {
            shortcuts[action] = action.defaultShortcut
            save(action)
        }
        for action in ShortcutAction.allCases where action.isGlobal { assign(action.defaultShortcut, to: action) }
    }

    // 예전 이름(설정 탭의 서랍 열기 줄)
    func beginHotKeyRecording() { beginRecording(.openDrawer) }
    func finishHotKeyRecording(_ new: Shortcut?) { if recordingAction == .openDrawer { finishRecording(new) } }
    func resetHotKey() { reset(.openDrawer) }

    private func assign(_ new: Shortcut, to action: ShortcutAction) {
        if action.isGlobal {
            let old = shortcuts[action]
            if onApplyHotKey?(action, new) == true {
                if shortcutMessage?.action == action { shortcutMessage = nil }
            } else {
                say(action, String(localized: "\(new.displayName)은(는) 다른 앱에서 쓰고 있어 바꾸지 못했어요. \(old.displayName)을(를) 그대로 써요."))
            }
            return
        }
        shortcuts[action] = new
        save(action)
        if shortcutMessage?.action == action { shortcutMessage = nil }
    }

    private func save(_ action: ShortcutAction) {
        guard !action.isGlobal else { return } // 전역 키는 AppDelegate가 저장(등록 성공 때만)
        UserDefaults.standard.set(ShortcutSet.pack(shortcuts[action]), forKey: SettingsKey.shortcut(action))
    }

    private func say(_ action: ShortcutAction, _ text: String) {
        shortcutMessage = (action, text)
    }

    /// 저장된 값 불러오기(서랍 열기는 AppDelegate가 따로)
    func loadShortcuts() {
        let d = UserDefaults.standard
        for action in ShortcutAction.allCases where !action.isGlobal {
            guard d.object(forKey: SettingsKey.shortcut(action)) != nil else { continue }
            let stored = ShortcutSet.unpack(d.integer(forKey: SettingsKey.shortcut(action)), fallback: action.defaultShortcut)
            if ShortcutSet.isOldTabDefault(stored, for: action) {
                // v0.2.2 기본값(1·2·3)이 그대로면 새 기본값(F1·F2·F3)으로. 직접 바꾼 값은 그대로 둔다.
                shortcuts[action] = action.defaultShortcut
                d.removeObject(forKey: SettingsKey.shortcut(action))
            } else {
                shortcuts[action] = stored
            }
        }
    }
}

/// 서랍 열기·닫기·위치 맞추기
@MainActor
final class DrawerController {
    let model = DrawerModel()

    private let panel = DrawerPanel()
    private let hosting: FirstClickHostingView<DrawerRootView>
    private var screen: NSScreen?
    private var globalMouseMonitor: Any?
    private var localKeyMonitor: Any?
    private var localMouseMonitor: Any?
    private let shortcutsPanel = DrawerPanel()
    private var columnPanels: [DrawerPanel] = []
    private let shortcutsHosting: FirstClickHostingView<ShortcutsView>

    var isOpen: Bool { panel.isVisible }

    init() {
        hosting = FirstClickHostingView(rootView: DrawerRootView(model: model))
        hosting.sizingOptions = [.intrinsicContentSize]
        panel.contentView = hosting
        shortcutsHosting = FirstClickHostingView(rootView: ShortcutsView(model: model))
        shortcutsHosting.sizingOptions = []
        shortcutsPanel.contentView = shortcutsHosting
        shortcutsPanel.debugName = "단축키 창"
        shortcutsPanel.level = NSWindow.Level(rawValue: panel.level.rawValue + 1)
        model.onToggleShortcutsWindow = { [weak self] in self?.toggleShortcutsWindow() }
        for level in 1...FavoriteColumns.maxColumns {
            let p = DrawerPanel()
            let h = FirstClickHostingView(rootView: FavoriteColumnView(model: model, level: level))
            h.sizingOptions = []
            p.contentView = h
            p.level = NSWindow.Level(rawValue: panel.level.rawValue + 1)
            p.hasShadow = true
            p.debugName = "폴더 창 \(level)"
            columnPanels.append(p)
        }
        model.onColumnsChanged = { [weak self] in self?.layoutColumns() }
        model.favorites.onChange = { [weak self] in self?.layoutColumns() }
        // 열어도 바로 닫지 않고, 마우스가 서랍·폴더 창 밖으로 나가면 닫는다(여러 개를 이어서 열 수 있게).
        // 설정 「열면 서랍 바로 닫기」를 켜면 열기가 끝나는 즉시 닫는다.
        model.onFavoriteOpened = { [weak self] in
            if UserDefaults.standard.object(forKey: SettingsKey.closeOnOpen) as? Bool ?? SettingsDefault.closeOnOpen {
                self?.close()
            } else {
                self?.closeWhenMouseLeaves()
            }
        }
        model.onChooseFiles = { [weak self] path in self?.chooseFiles(into: path) }
        model.onExportBackup = { [weak self] in self?.exportBackup() }
        model.onImportBackup = { [weak self] in self?.importBackup() }
        model.onTabChanged = { [weak self] tab in
            guard let self else { return }
            // 즐겨찾기에서 벗어나면 폴더 창·수정 모드 끝, 설정에서 벗어나면 단축키·색상 창 닫기(돌아와도 다시 열지 않음).
            if tab != .favorites {
                model.columnStack = []
                model.favoritesEditing = false
            }
            if tab != .settings {
                hideShortcutsWindow()
                BandColorPanel.shared.close()
            }
        }
        model.onLayoutChange = { [weak self] in
            DispatchQueue.main.async { self?.relayoutIfOpen() }
        }
        model.onShowColorPanel = { [weak self] key, fallback in
            guard let self else { return }
            BandColorPanel.shared.show(key: key, fallback: fallback, nextTo: panel.frame, above: panel.level)
        }
    }

    /// 「빠른 메모」: 서랍을 메모/할 일 탭으로 열고(이미 열려 있으면 그대로) 메모 칸에 글자 커서를 둔다.
    func quickMemo() {
        let wasOpen = isOpen
        open()
        guard isOpen else { return }   // 닫는 중이 아니라 열기에 실패한 경우
        model.tab = .notes
        // 탭 화면이 그려진 뒤에 커서를 요청한다(처음 열 때는 메모 칸이 아직 없다).
        DispatchQueue.main.asyncAfter(deadline: .now() + (wasOpen ? 0.02 : 0.12)) { [weak self] in
            self?.model.memoFocusRequest += 1
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
            model.memoRatio = Layout.clampedMemoRatio(defaults.double(forKey: SettingsKey.memoRatio))
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
            model.isDrawerOpen = true
            model.favorites.refreshMissing()
            model.onDrawerOpened?()
        }
        installMonitors()
    }

    func close() {
        guard isOpen else { return }
        // 할 일을 고치는 중이고 바뀐 내용이 있으면 닫지 않고 저장 확인 줄을 보인다.
        guard model.prepareToLeave(.close) else { return }
        model.finishRecording(nil)
        panel.orderOut(nil)
        closeAuxiliaryWindows()
        removeMonitors()
        model.isDrawerOpen = false
        if leaveTimer != nil { DebugOpenLog.write("유지 중 직접 닫힘") }
        stopLeaveTimer()
        model.favoritesEditing = false
        model.favorites.saveNow()
        model.onDrawerClosed?()
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
        if !model.columnStack.isEmpty { layoutColumns() }
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

    /// 탭에 딸린 보조 창(단축키 창, 색상 창, 즐겨찾기 목록 창). 탭을 바꾸거나 서랍을 닫으면 닫는다.
    private func closeAuxiliaryWindows() {
        hideShortcutsWindow()
        BandColorPanel.shared.close()
        model.columnStack = []
        model.favoritesEditing = false   // 탭을 바꾸거나 서랍을 닫으면 수정 모드도 끝
    }

    // MARK: 마우스가 나가면 닫기 (즐겨찾기를 연 뒤)

    private var leaveTimer: Timer?
    private var leaveTracker = Layout.LeaveTracker()

    /// 「실행 후 유지」: 서랍·폴더 창 영역(틈·여유 6pt 포함) 안에 마우스가 있으면 유지, 밖에 0.4초 머물면 닫기.
    /// 유지하는 동안만 0.1초마다 마우스 위치를 본다.
    private func closeWhenMouseLeaves() {
        guard isOpen else { return }
        if leaveTimer != nil { return }   // 이미 유지 중이면 그대로
        DebugOpenLog.write("실행 후 유지 시작")
        leaveTracker = Layout.LeaveTracker()
        let t = Timer(timeInterval: 0.1, repeats: true) { _ in
            MainActor.assumeIsolated { [weak self] in self?.checkMouseLeft() }
        }
        t.tolerance = 0.03
        RunLoop.main.add(t, forMode: .common)
        leaveTimer = t
    }

    private func checkMouseLeft() {
        guard isOpen else { stopLeaveTimer(); return }
        // 수정 모드에서는 자동으로 닫지 않는다(기존 규칙)
        if model.favoritesEditing { leaveTracker = Layout.LeaveTracker(); return }
        let frames = [panel.frame] + columnPanels.filter(\.isVisible).map(\.frame)
            + (shortcutsPanel.isVisible ? [shortcutsPanel.frame] : [])
        let inside = Layout.isInside(NSEvent.mouseLocation, frames: frames, margin: 6)
        if leaveTracker.update(inside: inside, now: ProcessInfo.processInfo.systemUptime) {
            stopLeaveTimer()
            DebugOpenLog.write("마우스 이탈 0.4초 → 서랍 닫기")
            close()
        }
    }

    private func stopLeaveTimer() {
        leaveTimer?.invalidate()
        leaveTimer = nil
    }

    // MARK: 즐겨찾기 목록 창 (서랍 옆, 최대 3칸)

    private func layoutColumns() {
        let stack = model.columnStack
        guard isOpen, let s = screen, !stack.isEmpty else {
            columnPanels.forEach { $0.orderOut(nil) }
            return
        }
        let d = UserDefaults.standard
        let t = CGFloat(Layout.clampedScale(d.double(forKey: SettingsKey.textScale)))
        let sc = CGFloat(Layout.clampedScale(d.double(forKey: SettingsKey.drawerScale)))
        var previous = panel.frame
        var goLeft = false
        for (i, p) in columnPanels.enumerated() {
            guard i < stack.count, let group = model.favorites.document.find(stack[i]) else {
                p.orderOut(nil)
                continue
            }
            let count = group.children?.count ?? 0
            // 보고된 높이(제목 + 고정 줄 + 항목·입력 줄, 최대 450). 아직 없으면 항목 수로 어림.
            let height = model.columnContentHeights[i + 1] ?? Layout.listWindowHeight(itemCount: count, rowHeight: 24 * t)
            let width = Layout.listWindowWidth(editing: model.favoritesEditing, scale: sc, text: t)
            let frame = Layout.listWindowFrame(after: previous, height: height, width: width,
                                               screenFrame: s.frame, preferLeft: goLeft)
            if frame.maxX <= previous.minX { goLeft = true }   // 한 번 왼쪽으로 가면 계속 왼쪽으로
            if p.frame != frame { p.setFrame(frame, display: true) }
            p.appearance = panel.appearance
            p.invalidateShadow()
            p.orderFrontRegardless()
            previous = frame
        }
    }

    /// 고르기·저장 창이 떠 있는 동안 true(바깥 클릭으로 서랍이 닫히지 않게 함)
    private(set) var filePanelOpen = false

    /// 고르기·저장 창을 서랍이 열려 있는 화면 한가운데에 띄운다. 끝난 뒤에도 잠깐 서랍을 유지한다.
    private func present(_ p: NSSavePanel, completion: @escaping @MainActor (NSApplication.ModalResponse) -> Void) {
        p.level = NSWindow.Level(rawValue: panel.level.rawValue + 2)
        let target = screen
        func place() {
            guard let s = target else { return }
            p.setFrameOrigin(Layout.centeredOrigin(size: p.frame.size, in: s.visibleFrame))
        }
        place()
        filePanelOpen = true
        NSApp.activate()
        p.begin { [weak self] response in
            MainActor.assumeIsolated {
                completion(response)
                // 창 안 마지막 클릭이 뒤늦게 전달돼도 닫히지 않도록 잠깐 더 유지
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(700))
                    self?.filePanelOpen = false
                }
            }
        }
        // 창이 뜬 뒤 저장돼 있던 옛 위치로 가 있으면 다시 맞춘다.
        DispatchQueue.main.async { if p.screen != target { place() } }
    }

    /// 앱·파일·폴더 고르기(여러 개). 열려 있는 동안 서랍은 닫히지 않는다(같은 앱의 창이라서).
    private func chooseFiles(into path: [UUID]) {
        let open = NSOpenPanel()
        open.canChooseFiles = true
        open.canChooseDirectories = true
        open.allowsMultipleSelection = true
        open.treatsFilePackagesAsDirectories = false
        open.prompt = String(localized: "추가")
        open.message = String(localized: "즐겨찾기에 넣을 앱·파일·Finder 폴더를 고르세요. 위치만 기억하고 복사하지 않아요.")
        present(open) { [weak self] response in
            guard response == .OK, let self else { return }
            self.model.favorites.add(urls: open.urls, at: path)
        }
    }

    /// 메모·할 일·즐겨찾기를 파일 하나로 저장(내 계정만 읽고 쓰게 600). 열려 있는 동안 서랍은 닫히지 않는다.
    private func exportBackup() {
        let save = NSSavePanel()
        save.nameFieldStringValue = BackupFile.suggestedFileName(date: Date())
        save.allowedContentTypes = [.json]
        save.canCreateDirectories = true
        save.prompt = String(localized: "내보내기")
        save.message = String(localized: "메모·할 일·즐겨찾기를 파일 하나로 저장해요. 메모 글이 그대로 들어 있으니 안전한 곳에 두세요.")
        present(save) { [weak self] response in
            guard response == .OK, let self, let url = save.url else { return }
            do {
                try self.model.makeBackup().encoded().write(to: url, options: [.atomic])
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                self.model.backupMessage = String(localized: "\(url.lastPathComponent)로 내보냈어요.")
            } catch {
                self.model.backupMessage = String(localized: "내보내지 못했어요: \(error.localizedDescription)")
            }
        }
    }

    /// 백업 파일 고르기 → 읽어서 설정 탭에 확인 줄을 띄운다(바로 바꾸지 않음).
    private func importBackup() {
        let open = NSOpenPanel()
        open.canChooseFiles = true
        open.canChooseDirectories = false
        open.allowsMultipleSelection = false
        open.allowedContentTypes = [.json]
        open.prompt = String(localized: "고르기")
        open.message = String(localized: "가져올 TopTiroir 백업 파일을 고르세요. 바꾸기 전에 한 번 더 확인해요.")
        present(open) { [weak self] response in
            guard response == .OK, let self, let url = open.url else { return }
            // 너무 큰 파일은 읽지 않는다(실수로 다른 파일을 고른 경우).
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard size <= 20_000_000, let data = try? Data(contentsOf: url) else {
                self.model.backupMessage = String(localized: "파일을 읽지 못했어요.")
                return
            }
            switch BackupFile.decode(data) {
            case .success(let file):
                self.model.backupMessage = nil
                self.model.pendingImport = file
            case .failure(let problem):
                self.model.backupMessage = problem.message
            }
        }
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
                // 즐겨찾기 수정 중에는 닫지 않는다(다른 앱에서 끌어 오려고 누른 것).
                // 고르기·저장 창이 떠 있는 동안에는 닫지 않는다(이 창은 다른 프로세스라 안의 클릭이 바깥 클릭으로 보임).
                if DrawerController.shared?.filePanelOpen == true { return }
                if FavoritesEditRules.autoCloses(editing: DrawerController.shared?.model.favoritesEditing == true,
                                                 closeMode: CloseMode(rawValue: mode ?? "") ?? .outsideOrEsc) {
                    DrawerController.shared?.close()
                }
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
                MainActor.assumeIsolated {
                    // 즐겨찾기 폴더 창이 있으면 가장 안쪽부터, 수정 중이면 서랍은 닫지 않는다.
                    guard let model = DrawerController.shared?.model else { return }
                    switch FavoritesEditRules.esc(editing: model.favoritesEditing, openColumns: model.columnStack.count) {
                    case .closeInnermostColumn: model.columnStack.removeLast()
                    case .nothing: break
                    case .closeDrawer: DrawerController.shared?.close()
                    }
                }
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

/// 앞에 있지 않은 서랍·폴더 창에서도 첫 클릭이 바로 단추·줄에 닿게 한다(창을 앞으로 가져오는 데 쓰이지 않게).
/// 또 마우스가 창 위에 오면 그 창이 바로 키 입력·마우스 올림을 받게(키 창으로) 한다.
/// 서랍·폴더 창은 앱을 활성으로 만들지 않는 창이라, 키 창이 아니면 마우스 올림 표시가 안 되고
/// 첫 클릭이 창을 깨우는 데 쓰여 줄이 눌리지 않을 수 있었다.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    private var enterArea: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let enterArea { removeTrackingArea(enterArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        enterArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if let w = window, w.isVisible, !w.isKeyWindow, w.canBecomeKey { w.makeKey() }
    }
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

    /// 진단 기록용 창 이름(서랍 / 폴더 창 1~3 / 단축키 창)
    var debugName = "서랍"

    /// 진단 기록(켜져 있을 때만): 마우스 누름·뗌이 이 창에 도착하는 즉시 한 줄
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .leftMouseUp {
            MainActor.assumeIsolated {
                guard DebugOpenLog.enabled else { return }
                let kind = DrawerController.shared?.model.hoveredFavoriteKind ?? "기타"
                let editing = DrawerController.shared?.model.favoritesEditing == true
                DebugOpenLog.write("마우스 \(event.type == .leftMouseDown ? "누름" : "뗌") 창=\(debugName) key=\(isKeyWindow) 앱활성=\(NSApp.isActive) 줄=\(kind) 수정=\(editing)")
            }
        }
        super.sendEvent(event)
    }
}
