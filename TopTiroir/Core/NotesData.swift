import Foundation

/// 할 일 한 줄
struct TodoItem: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var text: String
    var done: Bool
}

/// 메모와 할 일. 이 맥의 JSON 파일 하나에 저장한다(네트워크로 보내지 않음).
struct NotesDocument: Codable, Equatable, Sendable {
    var version = 1
    var memo = ""
    var todos: [TodoItem] = []

    init(memo: String = "", todos: [TodoItem] = []) {
        self.memo = memo
        self.todos = todos
    }

    /// 빠진 값이 있어도 읽을 수 있게 하나씩 꺼낸다(나중에 칸이 늘어도 예전 파일을 연다).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        memo = try c.decodeIfPresent(String.self, forKey: .memo) ?? ""
        todos = try c.decodeIfPresent([TodoItem].self, forKey: .todos) ?? []
    }

    // MARK: 할 일 다루기

    /// 앞뒤 공백을 빼고 맨 아래에 붙인다. 빈 글이면 false.
    @discardableResult
    mutating func addTodo(_ text: String, id: UUID = UUID()) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        todos.append(TodoItem(id: id, text: trimmed, done: false))
        return true
    }

    mutating func toggleTodo(id: UUID) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[i].done.toggle()
    }

    /// 글을 고친다. 앞뒤 공백을 빼고, 빈 글이면 바꾸지 않고 false.
    @discardableResult
    mutating func updateTodo(id: UUID, text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = todos.firstIndex(where: { $0.id == id }) else { return false }
        todos[i].text = trimmed
        return true
    }

    /// 수정 중인 글이 저장된 글과 달라 저장할 것이 있는지. 빈 글은 저장할 수 없으니 바뀐 것으로 보지 않는다.
    static func isEditChanged(original: String, draft: String) -> Bool {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != original
    }

    /// 끌어서 순서 바꾸기: id를 `slot`(옮기기 전 목록 기준 칸 번호, 0 = 맨 위, count = 맨 아래) 자리로 옮긴다.
    /// 제자리면 false.
    @discardableResult
    mutating func moveTodo(id: UUID, toSlot slot: Int) -> Bool {
        guard let from = todos.firstIndex(where: { $0.id == id }) else { return false }
        let s = min(max(slot, 0), todos.count)
        // 자기 바로 위·아래 칸은 제자리
        guard s != from, s != from + 1 else { return false }
        let item = todos.remove(at: from)
        todos.insert(item, at: s > from ? s - 1 : s)
        return true
    }

    /// 목록에서만 지운다.
    mutating func removeTodo(id: UUID) {
        todos.removeAll { $0.id == id }
    }

    /// 체크된 할 일만 목록에서 지운다.
    mutating func removeCompleted() {
        todos.removeAll { $0.done }
    }

    var remainingCount: Int { todos.filter { !$0.done }.count }
    var completedCount: Int { todos.count - remainingCount }

    // MARK: 파일 글자

    static func decode(_ data: Data) -> NotesDocument? {
        try? JSONDecoder().decode(NotesDocument.self, from: data)
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

/// 할 일 끌기 계산(화면 없이 테스트할 수 있게 분리)
enum TodoDrag {
    /// 끌어서 순서 바꾸기 전용 종류(메모·즐겨찾기가 글자·파일로 받지 않게)
    static let reorderType = "local.toptiroir.todo"

    /// 목록 안쪽 세로 위치(맨 위 = 0)에서 가장 가까운 칸 경계 번호(0...count)
    static func slot(contentY: CGFloat, rowHeight: CGFloat, count: Int) -> Int {
        guard rowHeight > 0, count > 0 else { return 0 }
        return min(max(Int((contentY / rowHeight).rounded()), 0), count)
    }

    /// 보이는 칸 위·아래 가장자리에 가까울수록 빨리 스크롤(초당 점 수). 위쪽은 음수, 가운데는 0.
    static func autoScrollSpeed(pointerY: CGFloat, viewportHeight: CGFloat,
                                edge: CGFloat = 28, maxSpeed: CGFloat = 420) -> CGFloat {
        guard viewportHeight > 0, edge > 0 else { return 0 }
        let e = min(edge, viewportHeight / 2)
        if pointerY < e { return -maxSpeed * min(1, (e - pointerY) / e) }
        if pointerY > viewportHeight - e { return maxSpeed * min(1, (pointerY - (viewportHeight - e)) / e) }
        return 0
    }
}
