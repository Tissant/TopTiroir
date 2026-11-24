import CoreGraphics

/// 화면 모서리 위치
enum ScreenCorner: CaseIterable, Sendable {
    case bottomLeft, bottomRight, topLeft, topRight
}

/// 띠·노치·서랍 위치 계산. AppKit 없이 숫자만 다루는 순수 함수라 단위 테스트할 수 있다.
/// 좌표는 macOS 화면 좌표(왼쪽 아래가 원점, 위로 갈수록 y 증가)를 쓴다.
enum Layout {
    static let drawerBaseWidth: CGFloat = 420
    static let scaleRange: ClosedRange<Double> = 0.8...1.4
    static let fallbackNotchWidth: CGFloat = 200
    static let screenCornerRadius: CGFloat = 16

    // MARK: 노치 화면 판별

    static func hasNotch(safeAreaTop: CGFloat, hasAuxiliaryArea: Bool) -> Bool {
        safeAreaTop > 0 || hasAuxiliaryArea
    }

    // MARK: 메뉴막대(띠) 높이

    /// 메뉴막대 높이 = 화면 위 끝 - 쓸 수 있는 영역 위 끝. 메뉴막대 자동 숨김 등으로 0이면 노치 높이로 대신한다.
    static func menuBarHeight(screenFrame: CGRect, visibleFrame: CGRect, safeAreaTop: CGFloat) -> CGFloat {
        let fromVisible = screenFrame.maxY - visibleFrame.maxY
        if fromVisible > 0 { return fromVisible }
        return max(safeAreaTop, 0)
    }

    /// 화면 맨 위 띠의 위치. 높이가 0 이하면 nil.
    static func bandRect(screenFrame: CGRect, height: CGFloat) -> CGRect? {
        guard height > 0 else { return nil }
        return CGRect(x: screenFrame.minX, y: screenFrame.maxY - height,
                      width: screenFrame.width, height: height)
    }

    // MARK: 노치 영역

    /// auxiliaryTopLeft/RightArea가 화면 기준(로컬) 좌표면 전체 좌표로 바꾼다.
    /// 이미 화면 안에 들어 있는 값이면 그대로 둔다.
    static func toGlobal(_ rect: CGRect, screenFrame: CGRect) -> CGRect {
        let alreadyGlobal = rect.minX >= screenFrame.minX && rect.maxX <= screenFrame.maxX
            && rect.minY >= screenFrame.minY && rect.maxY <= screenFrame.maxY
        if alreadyGlobal { return rect }
        return rect.offsetBy(dx: screenFrame.minX, dy: screenFrame.minY)
    }

    /// 노치(왼쪽 보조 영역과 오른쪽 보조 영역 사이)의 위치. 보조 영역 정보가 없으면 가운데 200pt로 대신한다.
    static func notchRect(screenFrame: CGRect, auxLeft: CGRect?, auxRight: CGRect?, height: CGFloat) -> CGRect {
        let top = screenFrame.maxY - height
        if let auxLeft, let auxRight {
            let left = toGlobal(auxLeft, screenFrame: screenFrame)
            let right = toGlobal(auxRight, screenFrame: screenFrame)
            let width = right.minX - left.maxX
            if width > 0 {
                return CGRect(x: left.maxX, y: top, width: width, height: height)
            }
        }
        let width = min(fallbackNotchWidth, screenFrame.width)
        return CGRect(x: screenFrame.midX - width / 2, y: top, width: width, height: height)
    }

    // MARK: 크기 비율

    /// 80~140%, 10% 단위로 맞춘다.
    static func clampedScale(_ value: Double) -> Double {
        guard value.isFinite else { return 1.0 }
        let stepped = (value * 10).rounded() / 10
        return min(max(stepped, scaleRange.lowerBound), scaleRange.upperBound)
    }

    static func percentText(_ scale: Double) -> String {
        "\(Int((clampedScale(scale) * 100).rounded()))%"
    }

    // MARK: 서랍

    static func drawerWidth(scale: Double) -> CGFloat {
        drawerBaseWidth * CGFloat(clampedScale(scale))
    }

    /// 서랍 최대 높이 = 화면 높이의 절반, 그래도 900pt를 넘지 않는다.
    static func maxDrawerHeight(screenFrame: CGRect) -> CGFloat {
        min(screenFrame.height / 2, drawerHeightLimit)
    }

    /// 서랍 위치: 메뉴막대 바로 아래 가운데. 높이는 내용에 맞추되 화면 절반을 넘지 않는다.
    static func drawerFrame(screenFrame: CGRect, menuBarHeight: CGFloat,
                            contentHeight: CGFloat, scale: Double) -> CGRect {
        let width = min(drawerWidth(scale: scale), screenFrame.width)
        let height = min(max(contentHeight, 1), maxDrawerHeight(screenFrame: screenFrame))
        let top = screenFrame.maxY - max(menuBarHeight, 0)
        var x = screenFrame.midX - width / 2
        x = min(max(x, screenFrame.minX), screenFrame.maxX - width)
        return CGRect(x: x, y: top - height, width: width, height: height)
    }

    // MARK: 마우스가 있는 화면

    /// 점이 들어 있는 화면 번호. 화면 맨 위 끝(maxY)도 그 화면으로 본다.
    static func screenIndex(containing point: CGPoint, frames: [CGRect]) -> Int? {
        frames.firstIndex { f in
            point.x >= f.minX && point.x < f.maxX && point.y >= f.minY && point.y <= f.maxY
        }
    }

    // MARK: 화면 모서리

    /// 네 모서리 칸. topInset(띠 높이)을 주면 위쪽 두 모서리를 띠 바로 아래에 둔다.
    static func cornerRects(screenFrame: CGRect, radius: CGFloat, topInset: CGFloat = 0) -> [(ScreenCorner, CGRect)] {
        let r = max(radius, 0)
        let f = screenFrame
        let top = f.maxY - max(topInset, 0)
        return [
            (.bottomLeft, CGRect(x: f.minX, y: f.minY, width: r, height: r)),
            (.bottomRight, CGRect(x: f.maxX - r, y: f.minY, width: r, height: r)),
            (.topLeft, CGRect(x: f.minX, y: top - r, width: r, height: r)),
            (.topRight, CGRect(x: f.maxX - r, y: top - r, width: r, height: r)),
        ]
    }

    /// 창을 화면 보이는 영역 한가운데(약간 위)에 놓을 때의 왼쪽 아래 좌표. 창이 화면보다 크면 화면 안쪽 가장자리에 맞춘다.
    static func centeredOrigin(size: CGSize, in visible: CGRect) -> CGPoint {
        let x = visible.midX - size.width / 2
        let y = visible.midY - size.height / 2 + visible.height * 0.05
        return CGPoint(x: max(visible.minX, min(x, visible.maxX - size.width)),
                       y: max(visible.minY, min(y, visible.maxY - size.height)))
    }
}
