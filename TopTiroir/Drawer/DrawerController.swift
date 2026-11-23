import AppKit
import Observation
import SwiftUI

enum DrawerTab: String, CaseIterable, Identifiable {
    case notes, favorites, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .notes: "메모/할 일"
        case .favorites: "즐겨찾기"
        case .settings: "설정"
        }
    }
}

/// 서랍 화면과 AppKit 쪽이 함께 보는 상태
@MainActor
@Observable
final class DrawerModel {
    var tab: DrawerTab = .settings
    var maxHeight: CGFloat = 500
    var contentHeight: CGFloat = 320
    var hotKeyAvailable = true

    @ObservationIgnored var onLayoutChange: (() -> Void)?
    @ObservationIgnored var onShowStatusItem: (() -> Void)?
    @ObservationIgnored var onShowColorPanel: (() -> Void)?

    func reportContentHeight(_ height: CGFloat) {
        guard abs(height - contentHeight) > 0.5 else { return }
        contentHeight = height
        onLayoutChange?()
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
        screen = s
        model.maxHeight = Layout.maxDrawerHeight(screenFrame: s.frame)
        relayout()
        panel.orderFrontRegardless()
        panel.makeKey()
        installMonitors()
    }

    func close() {
        guard isOpen else { return }
        panel.orderOut(nil)
        BandColorPanel.shared.close()
        removeMonitors()
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
            if event.keyCode == 53 { // esc
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
