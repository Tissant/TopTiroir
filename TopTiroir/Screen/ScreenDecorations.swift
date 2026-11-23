import AppKit

/// 노치 숨기기 띠(방식 B)와 화면 모서리 둥글게 오버레이.
/// 배경화면 파일은 건드리지 않는다. 창만 띄우므로 앱을 끄면 원래 모습으로 돌아간다.
@MainActor
final class ScreenDecorations {
    /// 바탕화면 아이콘 층 바로 위: 일반 창보다 아래, 반투명 메뉴막대 뒤에 검정이 비친다.
    private let bandLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    private let cornerLevel = NSWindow.Level.screenSaver

    private var band: OverlayWindow?
    private var corners: [ScreenCorner: OverlayWindow] = [:]

    func update() {
        let defaults = UserDefaults.standard
        let screen = NSScreen.ttBuiltInNotch
        let color = NSColor(ttHex: defaults.string(forKey: SettingsKey.bandColor) ?? SettingsDefault.bandColor)

        // 1) 노치 숨기기 띠
        if let screen, defaults.bool(forKey: SettingsKey.hideNotch),
           let rect = Layout.bandRect(screenFrame: screen.frame, height: screen.ttMenuBarHeight) {
            let w = band ?? OverlayWindow(level: bandLevel)
            band = w
            w.backgroundColor = color
            w.isOpaque = true
            if w.frame != rect { w.setFrame(rect, display: true) }
            w.orderFrontRegardless()
        } else {
            band?.orderOut(nil)
        }

        // 2) 화면 모서리 둥글게
        //    노치 숨기기가 켜져 있으면 위쪽 두 모서리를 띠 바로 아래에 띠 색으로 그려,
        //    검은 띠 아래 화면이 둥글게 시작하는 것처럼 보이게 한다. 아래 두 모서리는 검정.
        if let screen, defaults.bool(forKey: SettingsKey.roundCorners) {
            let bandOn = band?.isVisible == true
            let topInset = bandOn ? screen.ttMenuBarHeight : 0
            for (corner, rect) in Layout.cornerRects(screenFrame: screen.frame, radius: Layout.screenCornerRadius,
                                                     topInset: topInset) {
                let w = corners[corner] ?? makeCornerWindow(corner)
                corners[corner] = w
                let isTop = corner == .topLeft || corner == .topRight
                (w.contentView as? CornerView)?.color = (isTop && bandOn) ? color : .black
                if w.frame != rect { w.setFrame(rect, display: true) }
                w.orderFrontRegardless()
            }
        } else {
            corners.values.forEach { $0.orderOut(nil) }
        }
    }

    func removeAll() {
        band?.orderOut(nil)
        corners.values.forEach { $0.orderOut(nil) }
    }

    private func makeCornerWindow(_ corner: ScreenCorner) -> OverlayWindow {
        let w = OverlayWindow(level: cornerLevel)
        w.contentView = CornerView(corner: corner)
        return w
    }
}

/// 모서리 한 칸: 사각형에서 4분의 1 원을 뺀 부분만 칠한다.
final class CornerView: NSView {
    let corner: ScreenCorner
    var color: NSColor = .black { didSet { if color != oldValue { needsDisplay = true } } }

    init(corner: ScreenCorner) {
        self.corner = corner
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("코드로만 만든다") }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.width
        let center: NSPoint = switch corner {
        case .bottomLeft: NSPoint(x: r, y: r)
        case .bottomRight: NSPoint(x: 0, y: r)
        case .topLeft: NSPoint(x: r, y: 0)
        case .topRight: NSPoint(x: 0, y: 0)
        }
        let path = NSBezierPath(rect: bounds)
        path.appendOval(in: NSRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        path.windingRule = .evenOdd
        color.setFill()
        path.fill()
    }
}
