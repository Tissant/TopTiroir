import AppKit

/// 노치 자리에 놓는 보이지 않는 작은 창. 메뉴막대보다 위 층이라 노치 클릭·마우스 올림을 받는다.
@MainActor
final class NotchHotspot {
    var onClick: (() -> Void)?
    var onHover: (() -> Void)?

    private var window: NSPanel?

    func update() {
        guard let screen = NSScreen.ttBuiltInNotch else {
            window?.orderOut(nil)
            return
        }
        let rect = screen.ttNotchRect
        let w = window ?? makeWindow()
        window = w
        if w.frame != rect { w.setFrame(rect, display: false) }
        w.orderFrontRegardless()
    }

    private func makeWindow() -> NSPanel {
        let panel = HotspotPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        // 메뉴막대(mainMenu)보다 한 칸 위
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false // 투명해도 클릭을 받도록 명시
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        let view = HotspotView()
        view.onClick = { [weak self] in self?.onClick?() }
        view.onHover = { [weak self] in self?.onHover?() }
        panel.contentView = view
        return panel
    }
}

private final class HotspotPanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class HotspotView: NSView {
    var onClick: (() -> Void)?
    var onHover: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // 노치 자리는 실제 화소가 없어 보이지 않는다. 클릭을 확실히 받도록 아주 옅게 칠한다.
        NSColor.black.withAlphaComponent(0.01).setFill()
        bounds.fill()
    }

    override func mouseDown(with event: NSEvent) { onClick?() }

    override func mouseEntered(with event: NSEvent) { onHover?() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
}
