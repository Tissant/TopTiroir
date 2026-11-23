import AppKit

/// NSScreen 값을 Layout 순수 함수에 넘겨 주는 도우미
@MainActor
extension NSScreen {
    var ttHasNotch: Bool {
        Layout.hasNotch(safeAreaTop: safeAreaInsets.top, hasAuxiliaryArea: auxiliaryTopLeftArea != nil)
    }

    var ttMenuBarHeight: CGFloat {
        Layout.menuBarHeight(screenFrame: frame, visibleFrame: visibleFrame, safeAreaTop: safeAreaInsets.top)
    }

    var ttNotchRect: CGRect {
        Layout.notchRect(screenFrame: frame, auxLeft: auxiliaryTopLeftArea,
                         auxRight: auxiliaryTopRightArea, height: ttMenuBarHeight)
    }

    /// 노치가 있는 내장 화면(없으면 nil)
    static var ttBuiltInNotch: NSScreen? { screens.first { $0.ttHasNotch } }

    /// 마우스가 있는 화면
    static var ttUnderMouse: NSScreen? {
        let all = screens
        if let i = Layout.screenIndex(containing: NSEvent.mouseLocation, frames: all.map(\.frame)) {
            return all[i]
        }
        return main ?? all.first
    }
}

/// 테두리 없는 보조 창. macOS가 메뉴막대 아래로 밀어내지 않게 위치 보정을 끈다.
class OverlayWindow: NSWindow {
    init(level: NSWindow.Level) {
        super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        self.level = level
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

extension NSColor {
    convenience init(ttHex hex: String) {
        let rgb = HexColor.parse(hex) ?? HexColor.parse(SettingsDefault.bandColor)!
        self.init(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }

    var ttHex: String? {
        guard let c = usingColorSpace(.sRGB) else { return nil }
        return HexColor.format(RGB(red: c.redComponent, green: c.greenComponent, blue: c.blueComponent))
    }
}
