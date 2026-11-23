import CoreGraphics

/// 메모/할 일 서랍 길이와 투명도 계산
extension Layout {
    /// 서랍 전체 높이 상한(화면이 커도 이보다 길지 않다)
    static let drawerHeightLimit: CGFloat = 900
    static let notesMinHeight: CGFloat = 160
    static let notesDefaultHeight: CGFloat = 300

    /// 메모/할 일 영역 높이를 [최소, 상한] 안으로. 상한이 최소보다 작으면(아주 작은 화면) 상한을 쓴다.
    static func clampedNotesHeight(_ height: CGFloat, maxHeight: CGFloat) -> CGFloat {
        let upper = max(maxHeight, 0)
        guard height.isFinite else { return min(notesDefaultHeight, upper) }
        return min(max(height, min(notesMinHeight, upper)), upper)
    }

    /// 끌기: 마우스가 아래로 내려간 만큼(화면 좌표는 위로 갈수록 y가 크다) 길어진다.
    static func notesHeightAfterDrag(startHeight: CGFloat, startMouseY: CGFloat,
                                     currentMouseY: CGFloat, maxHeight: CGFloat) -> CGFloat {
        clampedNotesHeight(startHeight + (startMouseY - currentMouseY), maxHeight: maxHeight)
    }

    /// 메모:할 일 = 3:2. 사이 간격을 뺀 나머지를 나눈다.
    static func memoTodoSplit(total: CGFloat, spacing: CGFloat) -> (memo: CGFloat, todo: CGFloat) {
        let available = max(total - max(spacing, 0), 0)
        let memo = (available * 3 / 5).rounded()
        return (memo, available - memo)
    }

    // MARK: 투명도

    /// 서랍·창 투명도: 유리 배경에만 적용(글자는 그대로). 0이면 서랍이 사라져 20%까지만.
    static let windowOpacityRange: ClosedRange<Double> = 0.2...1.0
    /// 글자 투명도: 40% 아래로는 글자가 배경에 묻혀 읽기 어려워 막는다.
    static let textOpacityRange: ClosedRange<Double> = 0.4...1.0

    /// 범위 안, 5% 단위
    static func clampedOpacity(_ value: Double, range: ClosedRange<Double>) -> Double {
        guard value.isFinite else { return range.upperBound }
        let stepped = (value * 20).rounded() / 20
        return min(max(stepped, range.lowerBound), range.upperBound)
    }

    static func opacityPercentText(_ value: Double, range: ClosedRange<Double>) -> String {
        "\(Int((clampedOpacity(value, range: range) * 100).rounded()))%"
    }

    // MARK: 옆 창(단축키 보기)

    static func shortcutsWindowWidth(scale: Double) -> CGFloat {
        300 * CGFloat(clampedScale(scale))
    }

    /// 서랍 오른쪽에 서랍과 같은 높이로. 화면 오른쪽 밖으로 나가면 서랍 왼쪽에, 그래도 안 되면 화면 안쪽 끝에 붙인다.
    static func sideWindowFrame(drawer: CGRect, width: CGFloat, gap: CGFloat, screenFrame: CGRect) -> CGRect {
        let w = min(width, screenFrame.width)
        var x = drawer.maxX + gap
        if x + w > screenFrame.maxX {
            x = drawer.minX - gap - w
            if x < screenFrame.minX { x = screenFrame.maxX - w }
        }
        return CGRect(x: x, y: drawer.minY, width: w, height: drawer.height)
    }
}
