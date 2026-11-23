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
