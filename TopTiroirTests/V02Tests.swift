import CoreGraphics
import Foundation
import Testing

/// v0.2: 메모/할 일 데이터, 서랍 길이, 투명도, 단축키, 열 때 탭. 가짜 값만 쓴다(실제 파일 없음).
struct NotesDocumentTests {
    @Test func addTrimsAndSkipsEmpty() {
        var d = NotesDocument()
        let added = d.addTodo("  우유 사기 \n")
        let skipped = d.addTodo("   ")
        #expect(added)
        #expect(!skipped)
        #expect(d.todos.map(\.text) == ["우유 사기"])
        #expect(d.todos[0].done == false)
    }

    @Test func toggleAndRemove() {
        var d = NotesDocument()
        let a = UUID(), b = UUID()
        d.addTodo("하나", id: a)
        d.addTodo("둘", id: b)
        d.toggleTodo(id: a)
        #expect(d.todos[0].done)
        #expect(d.remainingCount == 1)
        d.removeTodo(id: a)
        #expect(d.todos.map(\.id) == [b])
        d.removeTodo(id: UUID()) // 없는 id는 무시
        #expect(d.todos.count == 1)
    }

    @Test func removeCompletedKeepsOpenOnes() {
        var d = NotesDocument()
        let a = UUID(), b = UUID(), c = UUID()
        d.addTodo("하나", id: a); d.addTodo("둘", id: b); d.addTodo("셋", id: c)
        d.toggleTodo(id: a); d.toggleTodo(id: c)
        #expect(d.completedCount == 2)
        d.removeCompleted()
        #expect(d.todos.map(\.id) == [b])
        #expect(d.completedCount == 0)
    }

    @Test func updateTodoText() {
        var d = NotesDocument()
        let a = UUID()
        d.addTodo("원래 글", id: a)
        let ok = d.updateTodo(id: a, text: "  고친 글 ")
        let empty = d.updateTodo(id: a, text: "   ")
        let missing = d.updateTodo(id: UUID(), text: "없음")
        #expect(ok && !empty && !missing)
        #expect(d.todos[0].text == "고친 글")
    }

    @Test func editChangedCheck() {
        #expect(!NotesDocument.isEditChanged(original: "우유", draft: "우유"))
        #expect(!NotesDocument.isEditChanged(original: "우유", draft: " 우유 "))   // 공백만 다름
        #expect(!NotesDocument.isEditChanged(original: "우유", draft: "   "))     // 빈 글은 저장 불가
        #expect(NotesDocument.isEditChanged(original: "우유", draft: "우유 2개"))
    }

    @Test func roundTrip() throws {
        var d = NotesDocument(memo: "첫 줄\n둘째 줄")
        d.addTodo("할 일")
        let back = NotesDocument.decode(try d.encoded())
        #expect(back == d)
    }

    @Test func decodesOldOrPartialFile() {
        let partial = Data(#"{"memo":"메모만"}"#.utf8)
        #expect(NotesDocument.decode(partial) == NotesDocument(memo: "메모만"))
        #expect(NotesDocument.decode(Data("망가진 파일".utf8)) == nil)
    }
}

struct DrawerSizingTests {
    @Test func notesHeightClamp() {
        #expect(Layout.clampedNotesHeight(300, maxHeight: 500) == 300)
        #expect(Layout.clampedNotesHeight(50, maxHeight: 500) == Layout.notesMinHeight)
        #expect(Layout.clampedNotesHeight(2000, maxHeight: 500) == 500)
        #expect(Layout.clampedNotesHeight(.nan, maxHeight: 500) == Layout.notesDefaultHeight)
        // 상한이 최소보다 작은 아주 작은 화면
        #expect(Layout.clampedNotesHeight(300, maxHeight: 100) == 100)
    }

    @Test func dragDownMakesLonger() {
        // 화면 좌표는 위가 큰 y. 마우스를 40 내리면 40 길어진다.
        #expect(Layout.notesHeightAfterDrag(startHeight: 300, startMouseY: 700, currentMouseY: 660, maxHeight: 500) == 340)
        #expect(Layout.notesHeightAfterDrag(startHeight: 300, startMouseY: 700, currentMouseY: 900, maxHeight: 500) == Layout.notesMinHeight)
        #expect(Layout.notesHeightAfterDrag(startHeight: 300, startMouseY: 700, currentMouseY: 0, maxHeight: 500) == 500)
    }

    @Test func splitIsThreeToTwo() {
        let s = Layout.memoTodoSplit(total: 508, spacing: 8)
        #expect(s.memo == 300)
        #expect(s.todo == 200)
        #expect(s.memo + s.todo == 500)
        let z = Layout.memoTodoSplit(total: 4, spacing: 8)
        #expect(z.memo == 0 && z.todo == 0)
    }

    @Test func maxHeightIsHalfButAtMost900() {
        #expect(Layout.maxDrawerHeight(screenFrame: CGRect(x: 0, y: 0, width: 1710, height: 1112)) == 556)
        #expect(Layout.maxDrawerHeight(screenFrame: CGRect(x: 0, y: 0, width: 3840, height: 2160)) == 900)
    }

    @Test(arguments: [(0.1, 0.2), (0.2, 0.2), (0.73, 0.75), (1.0, 1.0), (1.3, 1.0), (Double.nan, 1.0)])
    func windowOpacityClamp(input: Double, expected: Double) {
        #expect(Layout.clampedOpacity(input, range: Layout.windowOpacityRange) == expected)
    }

    @Test(arguments: [(0.1, 0.4), (0.4, 0.4), (0.62, 0.6), (1.0, 1.0), (Double.nan, 1.0)])
    func textOpacityClamp(input: Double, expected: Double) {
        #expect(Layout.clampedOpacity(input, range: Layout.textOpacityRange) == expected)
    }

    @Test func opacityText() {
        #expect(Layout.opacityPercentText(0.85, range: Layout.windowOpacityRange) == "85%")
        #expect(Layout.opacityPercentText(0.1, range: Layout.textOpacityRange) == "40%")
    }

    @Test func textScaleUsesSameRangeAsWindow() {
        // 글자 크기도 80~140%, 10% 단위
        #expect(Layout.clampedScale(0.5) == 0.8)
        #expect(Layout.clampedScale(1.26) == 1.3)
        #expect(Layout.percentText(1.4) == "140%")
    }
}

struct ShortcutTests {
    typealias M = Shortcut.Modifier

    @Test func defaultIsF12() {
        #expect(Shortcut.f12.displayName == "F12")
        #expect(Shortcut.check(keyCode: 111, modifiers: 0) == .ok)
    }

    @Test func names() {
        #expect(Shortcut(keyCode: 40, modifiers: M.command | M.shift).displayName == "⇧⌘K")
        #expect(Shortcut(keyCode: 49, modifiers: M.control | M.option).displayName == "⌃⌥Space")
        #expect(Shortcut(keyCode: 122, modifiers: 0).displayName == "F1")
        #expect(Shortcut.keyName(9999) == nil)
    }

    @Test func checks() {
        #expect(Shortcut.check(keyCode: 53, modifiers: 0) == .cancel)
        #expect(Shortcut.check(keyCode: 53, modifiers: M.command) == .cancel)
        #expect(Shortcut.check(keyCode: 0, modifiers: 0) == .needsModifier)           // A만
        #expect(Shortcut.check(keyCode: 0, modifiers: M.shift) == .needsModifier)     // ⇧A
        #expect(Shortcut.check(keyCode: 0, modifiers: M.option) == .needsModifier)    // ⌥A (macOS가 막음)
        #expect(Shortcut.check(keyCode: 0, modifiers: M.control) == .ok)
        #expect(Shortcut.check(keyCode: 0, modifiers: M.command | M.option) == .ok)
        #expect(Shortcut.check(keyCode: 105, modifiers: 0) == .ok)                    // F13
        #expect(Shortcut.check(keyCode: 9999, modifiers: M.command) == .unsupported)
    }

    @Test func storedValues() {
        #expect(Shortcut.stored(keyCode: 111, modifiers: 0) == .f12)
        #expect(Shortcut.stored(keyCode: 40, modifiers: Int(M.command)) == Shortcut(keyCode: 40, modifiers: M.command))
        #expect(Shortcut.stored(keyCode: -1, modifiers: 0) == .f12)
        #expect(Shortcut.stored(keyCode: 0, modifiers: 0) == .f12) // 수식 키 없는 글자 키는 쓰지 않음
    }
}

struct OpenTabTests {
    @Test func tabToOpen() {
        #expect(OpenTabMode.last.tab(lastTab: "settings") == .settings)
        #expect(OpenTabMode.last.tab(lastTab: nil) == .notes)
        #expect(OpenTabMode.last.tab(lastTab: "이상한값") == .notes)
        #expect(OpenTabMode.notes.tab(lastTab: "settings") == .notes)
        #expect(OpenTabMode.favorites.tab(lastTab: "settings") == .favorites)
    }
}
