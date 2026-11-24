import AppKit
import QuartzCore

/// 켜짐 표시: 화면마다 클릭이 통과하는 작은 창 하나. 움직임은 Core Animation이 맡고,
/// 남은 시간(막대 길이·점 개수)은 1초에 한 번만 바꾼다. 정지 효과는 애니메이션을 만들지 않는다.
@MainActor
final class IndicatorOverlay {
    private var windows: [OverlayWindow] = []
    private var views: [IndicatorView] = []
    private var style: IndicatorStyle = .bar

    /// 다시 배치(모양·색·화면이 바뀔 때)
    func show(style: IndicatorStyle, color: NSColor, fraction: Double, continuous: Bool) {
        removeAll()
        self.style = style
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        for screen in NSScreen.screens {
            let mb = screen.ttMenuBarHeight
            let notch: CGRect? = screen.ttHasNotch ? screen.ttNotchRect : nil
            let f = screen.frame
            let rect: CGRect
            switch style {
            case .bar, .lightStream: rect = Layout.indicatorBarRect(screenFrame: f, menuBarHeight: mb)
            case .breathe, .softHalo, .aurora: rect = Layout.indicatorHaloRect(screenFrame: f, menuBarHeight: mb)
            case .dotClock: rect = Layout.dotClockRect(screenFrame: f, menuBarHeight: mb, centerX: notch?.midX)
            case .notchHalo: rect = Layout.notchHaloRect(screenFrame: f, menuBarHeight: mb, notch: notch)
            }
            guard rect.width > 0, rect.height > 0 else { continue }
            // 메뉴막대(24층) 위층. 전체 화면 공간에는 따라가지 않는다(전체 화면 앱에선 숨김).
            let w = OverlayWindow(level: .statusBar)
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            w.setFrame(rect, display: false)
            // 노치 후광: 창 안에서 노치(또는 가운데 200pt) 자리
            let core = Layout.notchHaloRect(screenFrame: f, menuBarHeight: mb, notch: notch)
            let notchInWindow = CGRect(x: 22, y: 22, width: core.width - 44, height: mb)
            let v = IndicatorView(frame: NSRect(origin: .zero, size: rect.size), style: style, color: color,
                                  continuous: continuous, reduceMotion: reduceMotion, notchInWindow: notchInWindow)
            w.contentView = v
            v.setFraction(fraction, animated: false)
            w.orderFrontRegardless()
            windows.append(w)
            views.append(v)
        }
    }

    /// 1초마다: 남은 시간을 보여 주는 효과만 바꾼다.
    func update(fraction: Double) {
        guard style.showsRemaining else { return }
        views.forEach { $0.setFraction(fraction, animated: true) }
    }

    func removeAll() {
        views.forEach { $0.stopAnimations() }
        windows.forEach { $0.orderOut(nil) }
        windows = []
        views = []
    }
}

private final class IndicatorView: NSView {
    private let style: IndicatorStyle
    private let line = Layout.indicatorLineHeight
    // 막대·빛줄기
    private let track = CALayer()
    private let glowWide = CALayer()
    private let glowNear = CALayer()
    private let fill = CAGradientLayer()
    // 점 시계
    private var dots: [CALayer] = []

    init(frame: NSRect, style: IndicatorStyle, color: NSColor, continuous: Bool, reduceMotion: Bool, notchInWindow: CGRect) {
        self.style = style
        super.init(frame: frame)
        wantsLayer = true
        guard let root = layer else { return }
        let base = color.usingColorSpace(.sRGB) ?? color
        let rgb = RGB(red: Double(base.redComponent), green: Double(base.greenComponent), blue: Double(base.blueComponent))
        let light = Self.ns(HexColor.lightened(rgb, by: 0.55))
        let b = bounds
        let animate = !reduceMotion

        switch style {
        case .bar, .lightStream:
            buildLine(in: root, base: base, light: light)
            if !animate { break }
            if style == .bar {
                if continuous {
                    Self.breathe(fill, from: 0.7, to: 1.0, half: 3)
                    Self.breathe(glowNear, from: 0.5, to: 0.95, half: 3)
                } else {
                    addSweep(width: 120, alpha: 0.55, travel: 2.8, every: 7)   // 이따금 은은히
                }
            } else {
                addSweep(width: 170, alpha: 0.9, travel: 3.5, every: 5.5)      // 빛줄기: 3.5초 지나고 2초 쉼
            }

        case .breathe, .softHalo:
            // 숨 쉬는 네온 테두리: v0.3.0 1차 값의 1.1배. 소프트 후광: 더 옅고 움직이지 않음.
            let strong = style == .breathe
            let top = strong ? 0.352 : 0.18, mid = strong ? 0.11 : 0.055, edge = strong ? 0.935 : 0.4
            let container = Self.haloContainer(bounds: b, colors: [base.withAlphaComponent(top), base.withAlphaComponent(mid), base.withAlphaComponent(0)],
                                               edge: light.withAlphaComponent(edge))
            root.addSublayer(container)
            if strong {
                container.opacity = 0.825
                if animate { Self.breathe(container, from: 0.385, to: 0.88, half: 3) }   // 6초 주기
            }

        case .aurora:
            let cs = KeepAwake.auroraColors(rgb).map(Self.ns)
            let loop = cs + [cs[0]]                         // 끝과 처음이 이어지게
            let container = CALayer()
            container.frame = b
            // 흐르는 색 띠(창의 두 배 폭, 10초에 한 칸 흐름)
            let band = CAGradientLayer()
            band.colors = (loop + loop.dropFirst()).map { $0.withAlphaComponent(0.42).cgColor }
            band.startPoint = CGPoint(x: 0, y: 0.5)
            band.endPoint = CGPoint(x: 1, y: 0.5)
            band.frame = CGRect(x: 0, y: 0, width: b.width * 2, height: b.height)
            let fade = CAGradientLayer()                    // 위가 밝고 아래로 사라짐
            fade.frame = b
            fade.colors = [NSColor.white.cgColor, NSColor.white.withAlphaComponent(0.3).cgColor, NSColor.clear.cgColor]
            fade.locations = [0, 0.3, 1]
            fade.startPoint = CGPoint(x: 0.5, y: 1)
            fade.endPoint = CGPoint(x: 0.5, y: 0)
            let bandHolder = CALayer()
            bandHolder.frame = b
            bandHolder.addSublayer(band)
            bandHolder.mask = fade
            container.addSublayer(bandHolder)
            container.mask = Self.edgeFadeMask(bounds: b)
            root.addSublayer(container)
            if animate {
                let flow = CABasicAnimation(keyPath: "position.x")
                flow.fromValue = b.width
                flow.toValue = 0
                flow.duration = 10
                flow.repeatCount = .infinity
                band.add(flow, forKey: "flow")
            }

        case .dotClock:
            let size = Layout.clockDotSize, gap = Layout.clockDotGap
            for i in 0..<KeepAwake.clockDots {
                let d = CALayer()
                d.frame = CGRect(x: 8 + CGFloat(i) * (size + gap), y: b.height - size - 2, width: size, height: size)
                d.cornerRadius = size / 2
                d.backgroundColor = base.cgColor
                d.shadowColor = base.cgColor
                d.shadowRadius = 3
                d.shadowOpacity = 0.8
                d.shadowOffset = .zero
                root.addSublayer(d)
                dots.append(d)
                if continuous && animate {
                    // 모두 켜진 채 번갈아 숨 쉼
                    let a = CABasicAnimation(keyPath: "opacity")
                    a.fromValue = 0.45; a.toValue = 1
                    a.duration = 1.5; a.autoreverses = true; a.repeatCount = .infinity
                    a.timeOffset = Double(i % 2) * 1.5
                    a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    d.add(a, forKey: "breathe")
                }
            }

        case .notchHalo:
            // 노치 둘레로 번지는 빛(선 아님). 그림자 모양만 노치 자리로 준다.
            let glow = CALayer()
            glow.frame = b
            let path = CGPath(roundedRect: notchInWindow, cornerWidth: 10, cornerHeight: 10, transform: nil)
            glow.shadowPath = path
            glow.shadowColor = base.cgColor
            glow.shadowRadius = 11
            glow.shadowOpacity = 0.85
            glow.shadowOffset = .zero
            root.addSublayer(glow)
            glow.opacity = 0.8
            if animate { Self.breathe(glow, from: 0.45, to: 0.9, half: 3) }
        }
    }

    required init?(coder: NSCoder) { nil }

    // MARK: 남은 시간

    func setFraction(_ f: Double, animated: Bool) {
        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(1.0)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))
        } else {
            CATransaction.setDisableActions(true)
        }
        switch style {
        case .bar, .lightStream:
            let width = bounds.width * CGFloat(min(max(f, 0), 1))
            for l in [glowWide, glowNear, fill] { l.bounds.size.width = width }
        case .dotClock:
            for (d, o) in zip(dots, KeepAwake.dotOpacities(fraction: f)) where d.animation(forKey: "breathe") == nil {
                d.opacity = Float(o)
            }
        default:
            break
        }
        CATransaction.commit()
    }

    func stopAnimations() {
        func clear(_ l: CALayer) { l.removeAllAnimations(); l.sublayers?.forEach(clear) }
        if let root = layer { clear(root) }
    }

    // MARK: 만들기 도우미

    /// 가는 선(끝 둥긂) + 색→밝은 색 그라데이션 + 아래로 번지는 두 겹 빛
    private func buildLine(in root: CALayer, base: NSColor, light: NSColor) {
        let b = bounds
        let lineY = b.height - line
        track.frame = CGRect(x: 0, y: lineY, width: b.width, height: line)
        track.backgroundColor = base.withAlphaComponent(0.14).cgColor
        track.cornerRadius = line / 2
        for (g, radius, opacity) in [(glowWide, CGFloat(8), Float(0.22)), (glowNear, CGFloat(3), Float(0.45))] {
            g.backgroundColor = base.withAlphaComponent(0.9).cgColor
            g.cornerRadius = line / 2
            g.shadowColor = base.cgColor
            g.shadowRadius = radius
            g.shadowOpacity = opacity
            g.shadowOffset = CGSize(width: 0, height: -2)
            g.opacity = 0.9
        }
        fill.colors = [base.withAlphaComponent(0.75).cgColor, base.cgColor, light.cgColor]
        fill.locations = [0, 0.7, 1]
        fill.startPoint = CGPoint(x: 0, y: 0.5)
        fill.endPoint = CGPoint(x: 1, y: 0.5)
        fill.cornerRadius = line / 2
        fill.masksToBounds = true
        [track, glowWide, glowNear, fill].forEach(root.addSublayer)
        for l in [glowWide, glowNear, fill] {
            l.anchorPoint = CGPoint(x: 0, y: 0.5)   // 왼쪽 고정, 오른쪽 끝이 줄어든다
            l.bounds = CGRect(x: 0, y: 0, width: b.width, height: line)
            l.position = CGPoint(x: 0, y: lineY + line / 2)
        }
    }

    /// 선 위를 지나가는 밝은 빛(travel초 동안 지나가고 every초마다 반복)
    private func addSweep(width: CGFloat, alpha: CGFloat, travel: CFTimeInterval, every: CFTimeInterval) {
        let sweep = CAGradientLayer()
        sweep.colors = [NSColor.white.withAlphaComponent(0).cgColor, NSColor.white.withAlphaComponent(alpha).cgColor,
                        NSColor.white.withAlphaComponent(0).cgColor]
        sweep.startPoint = CGPoint(x: 0, y: 0.5)
        sweep.endPoint = CGPoint(x: 1, y: 0.5)
        sweep.frame = CGRect(x: -width, y: 0, width: width, height: line)
        fill.addSublayer(sweep)
        let move = CABasicAnimation(keyPath: "position.x")
        move.fromValue = -width / 2
        move.toValue = bounds.width + width / 2
        move.duration = travel
        move.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        let group = CAAnimationGroup()
        group.animations = [move]
        group.duration = every
        group.repeatCount = .infinity
        sweep.add(group, forKey: "sweep")
    }

    /// 메뉴막대 아래로 번지는 후광(위가 밝고 아래로 사라짐) + 1pt 가장자리 + 양 끝 부드럽게
    private static func haloContainer(bounds b: CGRect, colors: [NSColor], edge: NSColor) -> CALayer {
        let halo = CAGradientLayer()
        halo.frame = b
        halo.colors = colors.map(\.cgColor)
        halo.locations = [0, 0.35, 1]
        halo.startPoint = CGPoint(x: 0.5, y: 1)
        halo.endPoint = CGPoint(x: 0.5, y: 0)
        let edgeLayer = CALayer()
        edgeLayer.frame = CGRect(x: 0, y: b.height - 1, width: b.width, height: 1)
        edgeLayer.backgroundColor = edge.cgColor
        let container = CALayer()
        container.frame = b
        container.addSublayer(halo)
        container.addSublayer(edgeLayer)
        container.mask = edgeFadeMask(bounds: b)
        return container
    }

    /// 양 끝(12%)이 투명해지는 가로 가림막
    private static func edgeFadeMask(bounds b: CGRect) -> CALayer {
        let m = CAGradientLayer()
        m.frame = b
        m.colors = [NSColor.clear.cgColor, NSColor.white.cgColor, NSColor.white.cgColor, NSColor.clear.cgColor]
        m.locations = [0, 0.12, 0.88, 1]
        m.startPoint = CGPoint(x: 0, y: 0.5)
        m.endPoint = CGPoint(x: 1, y: 0.5)
        return m
    }

    private static func breathe(_ layer: CALayer, from: Float, to: Float, half: CFTimeInterval) {
        let a = CABasicAnimation(keyPath: "opacity")
        a.fromValue = from
        a.toValue = to
        a.duration = half
        a.autoreverses = true
        a.repeatCount = .infinity
        a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(a, forKey: "breathe")
    }

    private static func ns(_ c: RGB) -> NSColor {
        NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1)
    }
}
