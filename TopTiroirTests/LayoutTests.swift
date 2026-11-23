import CoreGraphics
import Testing

/// 가짜 숫자(15인치 맥북 화면 크기 비슷한 값)로만 테스트한다. 실제 파일·화면은 건드리지 않는다.
struct LayoutTests {
    let builtIn = CGRect(x: 0, y: 0, width: 1710, height: 1112)
    let builtInVisible = CGRect(x: 0, y: 0, width: 1710, height: 1075) // 메뉴막대 37

    // MARK: 띠 높이

    @Test func menuBarHeightFromVisibleFrame() {
        #expect(Layout.menuBarHeight(screenFrame: builtIn, visibleFrame: builtInVisible, safeAreaTop: 32) == 37)
    }

    @Test func menuBarHeightFallsBackToSafeArea() {
        // 메뉴막대 자동 숨김: visibleFrame이 화면 끝까지 → 노치 높이로 대신
        #expect(Layout.menuBarHeight(screenFrame: builtIn, visibleFrame: builtIn, safeAreaTop: 32) == 32)
        #expect(Layout.menuBarHeight(screenFrame: builtIn, visibleFrame: builtIn, safeAreaTop: 0) == 0)
    }

    @Test func bandRectSitsAtTop() {
        let r = Layout.bandRect(screenFrame: builtIn, height: 37)
        #expect(r == CGRect(x: 0, y: 1075, width: 1710, height: 37))
        #expect(Layout.bandRect(screenFrame: builtIn, height: 0) == nil)
    }

    @Test func bandRectOnOffsetScreen() {
        let s = CGRect(x: -1710, y: -200, width: 1710, height: 1112)
        #expect(Layout.bandRect(screenFrame: s, height: 37) == CGRect(x: -1710, y: 875, width: 1710, height: 37))
    }

    @Test func hasNotch() {
        #expect(Layout.hasNotch(safeAreaTop: 32, hasAuxiliaryArea: false))
        #expect(Layout.hasNotch(safeAreaTop: 0, hasAuxiliaryArea: true))
        #expect(!Layout.hasNotch(safeAreaTop: 0, hasAuxiliaryArea: false))
    }

    // MARK: 노치 영역

    @Test func notchRectBetweenAuxiliaryAreas() {
        let left = CGRect(x: 0, y: 1080, width: 755, height: 32)
        let right = CGRect(x: 955, y: 1080, width: 755, height: 32)
        let r = Layout.notchRect(screenFrame: builtIn, auxLeft: left, auxRight: right, height: 37)
        #expect(r == CGRect(x: 755, y: 1075, width: 200, height: 37))
    }

    @Test func notchRectConvertsLocalCoordinates() {
        // 내장 화면이 외부 모니터 왼쪽에 있을 때: 보조 영역 값이 화면 기준(0부터)이면 전체 좌표로 옮긴다
        let s = CGRect(x: -1710, y: 0, width: 1710, height: 1112)
        let left = CGRect(x: 0, y: 1080, width: 755, height: 32)
        let right = CGRect(x: 955, y: 1080, width: 755, height: 32)
        let r = Layout.notchRect(screenFrame: s, auxLeft: left, auxRight: right, height: 37)
        #expect(r.minX == -955)
        #expect(r.width == 200)
    }

    @Test func notchRectFallbackIsCentered() {
        let r = Layout.notchRect(screenFrame: builtIn, auxLeft: nil, auxRight: nil, height: 37)
        #expect(r == CGRect(x: 755, y: 1075, width: 200, height: 37))
    }

    // MARK: 크기 비율

    @Test(arguments: [
        (1.0, 1.0), (0.84, 0.8), (0.86, 0.9), (1.25, 1.3), (0.5, 0.8), (2.0, 1.4), (Double.nan, 1.0),
    ])
    func clampedScale(input: Double, expected: Double) {
        #expect(Layout.clampedScale(input) == expected)
    }

    @Test func percentText() {
        #expect(Layout.percentText(1.0) == "100%")
        #expect(Layout.percentText(1.3) == "130%")
        #expect(Layout.percentText(0.8) == "80%")
    }

    @Test func drawerWidthScales() {
        #expect(Layout.drawerWidth(scale: 1.0) == 420)
        #expect(abs(Layout.drawerWidth(scale: 1.4) - 588) < 0.001)
        #expect(abs(Layout.drawerWidth(scale: 0.8) - 336) < 0.001)
    }

    // MARK: 서랍 위치

    @Test func drawerIsCenteredBelowMenuBar() {
        let f = Layout.drawerFrame(screenFrame: builtIn, menuBarHeight: 37, contentHeight: 300, scale: 1.0)
        #expect(f == CGRect(x: 645, y: 1075 - 300, width: 420, height: 300))
    }

    @Test func drawerHeightIsLimitedToHalfScreen() {
        let f = Layout.drawerFrame(screenFrame: builtIn, menuBarHeight: 37, contentHeight: 5000, scale: 1.0)
        #expect(f.height == 556)
        #expect(f.maxY == 1075)
    }

    @Test func drawerOnExternalScreen() {
        let ext = CGRect(x: 1710, y: 0, width: 2560, height: 1440)
        let f = Layout.drawerFrame(screenFrame: ext, menuBarHeight: 24, contentHeight: 200, scale: 1.0)
        #expect(f == CGRect(x: 1710 + 1280 - 210, y: 1416 - 200, width: 420, height: 200))
    }

    @Test func drawerNeverWiderThanScreen() {
        let tiny = CGRect(x: 0, y: 0, width: 400, height: 300)
        let f = Layout.drawerFrame(screenFrame: tiny, menuBarHeight: 24, contentHeight: 100, scale: 1.4)
        #expect(f.width == 400)
        #expect(f.minX == 0)
    }

    // MARK: 마우스가 있는 화면

    @Test func screenIndexFindsScreen() {
        let frames = [builtIn, CGRect(x: 1710, y: 0, width: 2560, height: 1440)]
        #expect(Layout.screenIndex(containing: CGPoint(x: 100, y: 100), frames: frames) == 0)
        #expect(Layout.screenIndex(containing: CGPoint(x: 2000, y: 1440), frames: frames) == 1) // 맨 위 끝
        #expect(Layout.screenIndex(containing: CGPoint(x: -5, y: 100), frames: frames) == nil)
    }

    // MARK: 화면 모서리

    @Test func cornerRects() {
        let rects = Layout.cornerRects(screenFrame: builtIn, radius: 10)
        #expect(rects.count == 4)
        let tr = rects.first { $0.0 == .topRight }?.1
        #expect(tr == CGRect(x: 1700, y: 1102, width: 10, height: 10))
    }

    @Test func topCornersSitBelowBand() {
        let rects = Layout.cornerRects(screenFrame: builtIn, radius: 16, topInset: 37)
        let tl = rects.first { $0.0 == .topLeft }?.1
        let bl = rects.first { $0.0 == .bottomLeft }?.1
        #expect(tl == CGRect(x: 0, y: 1112 - 37 - 16, width: 16, height: 16))
        #expect(bl == CGRect(x: 0, y: 0, width: 16, height: 16)) // 아래 모서리는 그대로
    }
}

struct HexColorTests {
    @Test func parseBrandBlack() {
        let c = HexColor.parse("#0B0C10")
        #expect(c == RGB(red: 11.0 / 255, green: 12.0 / 255, blue: 16.0 / 255))
    }

    @Test func parseRejectsBadText() {
        #expect(HexColor.parse("#12345") == nil)
        #expect(HexColor.parse("hello!") == nil)
    }

    @Test func roundTrip() {
        for hex in ["#0B0C10", "#F5A623", "#000000", "#FFFFFF"] {
            #expect(HexColor.format(HexColor.parse(hex)!) == hex)
        }
    }

    @Test func formatClampsOutOfRange() {
        #expect(HexColor.format(RGB(red: 2, green: -1, blue: 0.5)) == "#FF0080")
    }
}
