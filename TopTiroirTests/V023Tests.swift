import CoreGraphics
import Testing

/// v0.2.3: 메모/할 일 사이 손잡이(비율), 최소 높이
struct MemoSplitTests {
    @Test func defaultIsThreeToTwo() {
        let s = Layout.memoTodoSplit(total: 508, spacing: 8)
        #expect(s.memo == 300 && s.todo == 200)
    }

    @Test func ratioKeptWhenDrawerResizes() {
        let a = Layout.memoTodoSplit(total: 408, spacing: 8, memoRatio: 0.3)
        let b = Layout.memoTodoSplit(total: 808, spacing: 8, memoRatio: 0.3)
        #expect(a.memo == 120 && a.todo == 280)
        #expect(b.memo == 240 && b.todo == 560)
    }

    @Test func minimumHeights() {
        // 할 일 최소 100: 메모 몫 80%여도 할 일은 100 남김
        let s = Layout.memoTodoSplit(total: 308, spacing: 8, memoRatio: 0.8, memoMin: 40, todoMin: 100)
        #expect(s.todo == 100 && s.memo == 200)
        // 메모 최소 60
        let m = Layout.memoTodoSplit(total: 308, spacing: 8, memoRatio: 0.2, memoMin: 60, todoMin: 100)
        #expect(m.memo == 60)
        // 너무 좁으면 할 일 최소 먼저
        let tiny = Layout.memoTodoSplit(total: 108, spacing: 8, memoRatio: 0.5, memoMin: 60, todoMin: 100)
        #expect(tiny.todo == 100 && tiny.memo == 0)
    }

    @Test func dragChangesRatio() {
        // 사용할 수 있는 높이 500에서 마우스를 50 내리면 +0.1
        #expect(abs(Layout.memoRatioAfterDrag(startRatio: 0.6, startMouseY: 700, currentMouseY: 650, available: 500) - 0.7) < 0.0001)
        #expect(Layout.memoRatioAfterDrag(startRatio: 0.6, startMouseY: 700, currentMouseY: 0, available: 500) == 0.8)
        #expect(Layout.memoRatioAfterDrag(startRatio: 0.6, startMouseY: 0, currentMouseY: 700, available: 500) == 0.2)
        #expect(Layout.clampedMemoRatio(.nan) == 0.6)
    }
}
