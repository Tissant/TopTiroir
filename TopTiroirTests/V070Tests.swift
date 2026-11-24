import Foundation
import Testing

/// v0.7.0: 할 일 순서 바꾸기·끌기 중 자동 스크롤 계산
struct TodoReorderTests {
    func doc() -> NotesDocument {
        var d = NotesDocument()
        for t in ["a", "b", "c", "d"] { d.addTodo(t) }
        return d
    }
    func texts(_ d: NotesDocument) -> [String] { d.todos.map(\.text) }

    @Test(arguments: [(0, 3, ["b", "c", "a", "d"]), (0, 4, ["b", "c", "d", "a"]),
                      (3, 0, ["d", "a", "b", "c"]), (2, 1, ["a", "c", "b", "d"]),
                      (1, 99, ["a", "c", "d", "b"]), (3, -5, ["d", "a", "b", "c"])])
    func move(from: Int, slot: Int, expected: [String]) {
        var d = doc()
        let moved = d.moveTodo(id: d.todos[from].id, toSlot: slot)
        #expect(moved)
        #expect(texts(d) == expected)
    }

    @Test func sameSpotIsNoChange() {
        var d = doc()
        let id = d.todos[1].id
        let up = d.moveTodo(id: id, toSlot: 1)      // 바로 위 칸
        let down = d.moveTodo(id: id, toSlot: 2)    // 바로 아래 칸
        let unknown = d.moveTodo(id: UUID(), toSlot: 0)
        #expect(!up && !down && !unknown)
        #expect(texts(d) == ["a", "b", "c", "d"])
    }

    @Test func keepsDoneState() {
        var d = doc()
        d.toggleTodo(id: d.todos[0].id)
        _ = d.moveTodo(id: d.todos[0].id, toSlot: 4)
        #expect(d.todos.last?.done == true)
        #expect(d.todos.count == 4)
    }

    @Test func slotFromPosition() {
        #expect(TodoDrag.slot(contentY: 0, rowHeight: 22, count: 4) == 0)
        #expect(TodoDrag.slot(contentY: 10, rowHeight: 22, count: 4) == 0)
        #expect(TodoDrag.slot(contentY: 12, rowHeight: 22, count: 4) == 1)
        #expect(TodoDrag.slot(contentY: 500, rowHeight: 22, count: 4) == 4)
        #expect(TodoDrag.slot(contentY: -9, rowHeight: 22, count: 4) == 0)
        #expect(TodoDrag.slot(contentY: 5, rowHeight: 22, count: 0) == 0)
    }

    @Test func autoScrollSpeed() {
        #expect(TodoDrag.autoScrollSpeed(pointerY: 100, viewportHeight: 200) == 0)
        #expect(TodoDrag.autoScrollSpeed(pointerY: 0, viewportHeight: 200) == -420)
        #expect(TodoDrag.autoScrollSpeed(pointerY: 200, viewportHeight: 200) == 420)
        let slow = TodoDrag.autoScrollSpeed(pointerY: 20, viewportHeight: 200)
        #expect(slow < 0 && slow > -420)
        #expect(TodoDrag.autoScrollSpeed(pointerY: 5, viewportHeight: 0) == 0)
    }
}
