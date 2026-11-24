import Foundation

/// 즐겨찾기: 폴더(즐겨찾기용, 3단계까지)·앱·웹 주소·파일·Finder 폴더. 파일은 복사하지 않고 위치(북마크)만 저장한다.

enum FavoriteKind: String, Codable, Sendable {
    case group, app, url, file, folder
    /// 목록 구분선(눌러도 아무 일 없음)
    case separator
}

struct FavoriteItem: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var kind: FavoriteKind
    var name: String
    /// 앱·파일·폴더: 북마크(옮기거나 이름이 바뀌어도 찾아감)
    var bookmark: Data?
    /// 앱·파일·폴더: 추가할 때의 경로(중복 검사·북마크가 깨졌을 때 안내용). 웹 주소: 주소.
    var location: String?
    /// 묶음 안 항목
    var children: [FavoriteItem]?

    init(id: UUID = UUID(), kind: FavoriteKind, name: String, bookmark: Data? = nil,
         location: String? = nil, children: [FavoriteItem]? = nil) {
        self.id = id
        self.kind = kind
        self.name = name
        self.bookmark = bookmark
        self.location = location
        self.children = kind == .group ? (children ?? []) : nil
    }

    static func separator(id: UUID = UUID()) -> FavoriteItem {
        FavoriteItem(id: id, kind: .separator, name: "구분선")
    }

    static func group(_ name: String, id: UUID = UUID(), children: [FavoriteItem] = []) -> FavoriteItem {
        FavoriteItem(id: id, kind: .group, name: name, children: children)
    }

    /// 같은 위치에 이미 있으면 중복: 묶음은 이름, 나머지는 종류 + 위치(경로·주소)
    func isSame(as other: FavoriteItem) -> Bool {
        guard kind == other.kind, kind != .separator else { return false }   // 구분선은 여러 개 가능
        if kind == .group { return name.compare(other.name, options: .caseInsensitive) == .orderedSame }
        guard let a = location, let b = other.location else { return false }
        return kind == .url ? a.lowercased() == b.lowercased() : a == b
    }

    /// 창 제목 「이름 · N개」에 쓰는 개수(구분선은 빼고 바로 안의 항목만)
    var visibleChildCount: Int { (children ?? []).filter { $0.kind != .separator }.count }

    /// 안에 든 항목 수(폴더 안 폴더 포함, 자기 자신 제외)
    var descendantCount: Int {
        (children ?? []).reduce(0) { $0 + 1 + $1.descendantCount }
    }

    /// 폴더 깊이: 폴더가 아니면 0, 빈 폴더는 1, 안에 폴더가 있으면 1 + 가장 깊은 안쪽 폴더
    var groupDepth: Int {
        guard kind == .group else { return 0 }
        return 1 + ((children ?? []).map(\.groupDepth).max() ?? 0)
    }
}

enum FavoriteAddResult: Equatable, Sendable {
    case added, duplicate(String), noSuchGroup, tooDeep
}

/// 끌어서 옮기기 결과
enum FavoriteRelocateResult: Equatable, Sendable {
    case moved, unchanged, tooDeep, intoItself, duplicate(String), notFound
}

/// favorites.json 내용. path = 바깥에서 안으로 들어가는 묶음 id들(빈 배열 = 맨 위 목록).
struct FavoritesDocument: Codable, Equatable, Sendable {
    var version = 1
    var items: [FavoriteItem] = []

    init(items: [FavoriteItem] = []) { self.items = items }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        items = try c.decodeIfPresent([FavoriteItem].self, forKey: .items) ?? []
    }

    // MARK: 찾기

    func list(at path: [UUID]) -> [FavoriteItem]? {
        var current = items
        for id in path {
            guard let g = current.first(where: { $0.id == id }), g.kind == .group else { return nil }
            current = g.children ?? []
        }
        return current
    }

    func item(_ id: UUID, at path: [UUID]) -> FavoriteItem? {
        list(at: path)?.first { $0.id == id }
    }

    /// 어디에 있든 id로 찾기(묶음 창 제목 등)
    func find(_ id: UUID) -> FavoriteItem? {
        func search(_ list: [FavoriteItem]) -> FavoriteItem? {
            for i in list {
                if i.id == id { return i }
                if let found = search(i.children ?? []) { return found }
            }
            return nil
        }
        return search(items)
    }

    // MARK: 바꾸기

    /// path 목록을 바꾸는 공통 도우미
    private mutating func edit(at path: [UUID], _ change: (inout [FavoriteItem]) -> Void) -> Bool {
        func walk(_ list: inout [FavoriteItem], _ rest: ArraySlice<UUID>) -> Bool {
            guard let first = rest.first else { change(&list); return true }
            guard let i = list.firstIndex(where: { $0.id == first && $0.kind == .group }) else { return false }
            var children = list[i].children ?? []
            let ok = walk(&children, rest.dropFirst())
            list[i].children = children
            return ok
        }
        return walk(&items, path[...])
    }

    /// 폴더(묶음)는 3단계까지: 맨 위 목록의 폴더가 1단계.
    static let maxGroupDepth = 3

    /// 이 목록(path)에 폴더를 새로 만들 수 있는지
    static func canAddGroup(at path: [UUID]) -> Bool { path.count < maxGroupDepth }

    @discardableResult
    mutating func add(_ item: FavoriteItem, at path: [UUID]) -> FavoriteAddResult {
        guard let list = list(at: path) else { return .noSuchGroup }
        if item.kind == .group && !Self.canAddGroup(at: path) { return .tooDeep }
        if let dup = list.first(where: { $0.isSame(as: item) }) { return .duplicate(dup.name) }
        _ = edit(at: path) { $0.append(item) }
        return .added
    }

    /// 목록에서만 지운다(실제 파일은 건드리지 않음).
    @discardableResult
    mutating func remove(_ id: UUID, at path: [UUID]) -> Bool {
        var removed = false
        _ = edit(at: path) { list in
            let before = list.count
            list.removeAll { $0.id == id }
            removed = list.count != before
        }
        return removed
    }

    @discardableResult
    mutating func rename(_ id: UUID, to name: String, at path: [UUID]) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        var done = false
        _ = edit(at: path) { list in
            if let i = list.firstIndex(where: { $0.id == id }) { list[i].name = trimmed; done = true }
        }
        return done
    }

    /// 한 칸 위(-1)·아래(+1)로
    @discardableResult
    mutating func move(_ id: UUID, by offset: Int, at path: [UUID]) -> Bool {
        var done = false
        _ = edit(at: path) { list in
            guard let i = list.firstIndex(where: { $0.id == id }) else { return }
            let j = i + offset
            guard list.indices.contains(j) else { return }
            list.swapAt(i, j)
            done = true
        }
        return done
    }

    /// 이 항목이 들어 있는 목록의 path
    func parentPath(of id: UUID) -> [UUID]? {
        func search(_ list: [FavoriteItem], _ path: [UUID]) -> [UUID]? {
            for i in list {
                if i.id == id { return path }
                if i.kind == .group, let found = search(i.children ?? [], path + [i.id]) { return found }
            }
            return nil
        }
        return search(items, [])
    }

    /// 끌어서 옮기기: 어디에 있든 id를 target 목록의 before 자리로(nil = 맨 끝).
    /// 폴더는 자기 안쪽 폴더 깊이까지 합쳐 3단계를 넘으면 막고, 자기 안으로는 못 옮긴다.
    @discardableResult
    mutating func relocate(_ id: UUID, to target: [UUID], before: UUID?) -> FavoriteRelocateResult {
        guard let from = parentPath(of: id), let item = self.item(id, at: from), list(at: target) != nil else { return .notFound }
        if from == target { return move(id, before: before, at: target) ? .moved : .unchanged }
        if target.contains(id) { return .intoItself }
        if item.kind == .group && target.count + item.groupDepth > Self.maxGroupDepth { return .tooDeep }
        if let dup = list(at: target)?.first(where: { $0.isSame(as: item) }) { return .duplicate(dup.name) }
        remove(id, at: from)
        _ = edit(at: target) { list in
            if let before, let i = list.firstIndex(where: { $0.id == before }) { list.insert(item, at: i) }
            else { list.append(item) }
        }
        return .moved
    }

    /// 3단계를 넘는 폴더를 지우지 않고 한 단계씩 끌어올린다(3단계 폴더가 든 목록의 맨 끝으로). 옮긴 개수.
    @discardableResult
    mutating func flattenTooDeep() -> Int {
        var moved = 0
        while true {
            // 4단계 폴더 하나 찾기: path(3단계 폴더까지 3개) 안의 폴더
            func find(_ list: [FavoriteItem], _ path: [UUID]) -> ([UUID], UUID)? {
                for i in list where i.kind == .group {
                    let p = path + [i.id]
                    if p.count == Self.maxGroupDepth, let deep = (i.children ?? []).first(where: { $0.kind == .group }) {
                        return (p, deep.id)
                    }
                    if let f = find(i.children ?? [], p) { return f }
                }
                return nil
            }
            guard let (holder, deepId) = find(items, []), let deep = item(deepId, at: holder) else { break }
            remove(deepId, at: holder)
            let up = Array(holder.dropLast())          // 3단계 폴더가 든 목록
            _ = edit(at: up) { $0.append(deep) }
            moved += 1
        }
        return moved
    }

    /// 끌어서 순서 바꾸기: id를 target 자리로(target이 nil이면 맨 끝으로). 같은 목록 안에서만.
    @discardableResult
    mutating func move(_ id: UUID, before target: UUID?, at path: [UUID]) -> Bool {
        guard id != target else { return false }
        var done = false
        _ = edit(at: path) { list in
            guard let from = list.firstIndex(where: { $0.id == id }) else { return }
            if let target, !list.contains(where: { $0.id == target }) { return }
            let item = list.remove(at: from)
            if let target, let to = list.firstIndex(where: { $0.id == target }) {
                // 아래로 옮길 때는 대상의 뒤로(끌어 놓은 줄 자리에 오도록)
                list.insert(item, at: from <= to ? to + 1 : to)
            } else {
                list.append(item)
            }
            done = true
        }
        return done
    }

    // MARK: 파일

    static func decode(_ data: Data) -> FavoritesDocument? {
        try? JSONDecoder().decode(FavoritesDocument.self, from: data)
    }

    func encoded() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(self)
    }
}

/// 웹 주소 검사: http·https만. 「example.com」처럼 형식이 빠지면 https를 붙인다.
enum FavoriteURL {
    enum Problem: Error, Equatable, Sendable { case empty, spaces, scheme, invalid }

    static func validate(_ text: String) -> Result<URL, Problem> {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return .failure(.empty) }
        guard !t.contains(where: \.isWhitespace) else { return .failure(.spaces) }
        let withScheme: String
        if let r = t.range(of: "://") {
            let scheme = t[..<r.lowerBound].lowercased()
            guard scheme == "http" || scheme == "https" else { return .failure(.scheme) }
            withScheme = t
        } else if t.contains(":") && !t.contains(".") {
            return .failure(.scheme)                    // mailto:, file: 같은 것
        } else if t.lowercased().hasPrefix("file:") || t.lowercased().hasPrefix("javascript:") {
            return .failure(.scheme)
        } else {
            withScheme = "https://" + t
        }
        guard let url = URL(string: withScheme), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https", let host = url.host, host.contains(".") || host == "localhost"
        else { return .failure(.invalid) }
        return .success(url)
    }

    static func message(_ p: Problem) -> String {
        switch p {
        case .empty: "주소를 적어 주세요."
        case .spaces: "주소에 띄어쓰기가 있어요."
        case .scheme: "http나 https로 시작하는 웹 주소만 넣을 수 있어요."
        case .invalid: "웹 주소 형식이 아니에요. 예: https://example.com"
        }
    }

    /// 이름을 비워 두면 주소의 사이트 이름을 쓴다.
    static func defaultName(for url: URL) -> String {
        (url.host ?? url.absoluteString).replacingOccurrences(of: "www.", with: "")
    }
}

/// 오른쪽 목록 창 단계(최대 3칸). stack[i] = i+1번째 칸에 열린 폴더 id.
enum FavoriteColumns {
    static let maxColumns = 3

    /// level: 누른 폴더가 있던 곳(0 = 서랍 목록, 1 = 첫째 칸 …)
    /// 폴더가 3단계까지라 칸도 최대 3개(넘는 요청은 무시)
    static func toggle(_ id: UUID, fromLevel level: Int, stack: [UUID]) -> [UUID] {
        let keep = Array(stack.prefix(level))
        if stack.count > level, stack[level] == id { return keep }       // 같은 폴더 다시 → 닫기
        guard level < maxColumns else { return stack }
        return keep + [id]
    }
}

extension Layout {
    static let favoriteRowHeight: CGFloat = 24
    static let listWindowWidth: CGFloat = 168
    static let listWindowMaxHeight: CGFloat = 450
    static let listWindowPadding: CGFloat = 6
    static let listWindowHeader: CGFloat = 22

    /// 목록 창 높이: 제목 + 줄들 + 「+ 추가…」 줄 + 위아래 여백. 450을 넘으면 450(안에서 스크롤).
    static func listWindowHeight(itemCount: Int, rowHeight: CGFloat = favoriteRowHeight) -> CGFloat {
        let rows = CGFloat(max(itemCount, 1) + 1)           // 비어 있어도 안내 한 줄 + 추가 줄
        let h = listWindowPadding * 2 + listWindowHeader + rows * rowHeight + 1
        return min(h, listWindowMaxHeight)
    }

    /// 목록 창 위치: 앞 창(서랍 또는 이전 칸) 오른쪽, 위를 맞춤. 화면 밖이면 왼쪽으로.
    static func listWindowFrame(after previous: CGRect, height: CGFloat, width: CGFloat = listWindowWidth,
                                gap: CGFloat = 6, screenFrame: CGRect, preferLeft: Bool = false) -> CGRect {
        let top = previous.maxY
        var x = preferLeft ? previous.minX - gap - width : previous.maxX + gap
        if !preferLeft && x + width > screenFrame.maxX { x = previous.minX - gap - width }
        if x < screenFrame.minX { x = min(previous.maxX + gap, screenFrame.maxX - width) }
        var y = top - height
        if y < screenFrame.minY { y = screenFrame.minY }
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

/// 항목을 눌렀을 때 할 일(실제로 여는 일은 앱 쪽 FavoriteOpening이 한다)
enum FavoriteAction: Equatable, Sendable {
    case launchApp(URL), openFile(URL), revealFolder(URL), openWeb(URL), toggleGroup, missing, nothing

    /// resolved: 북마크로 찾은 위치(못 찾으면 nil)
    static func decide(_ item: FavoriteItem, resolved: URL?) -> FavoriteAction {
        switch item.kind {
        case .separator: return .nothing
        case .group: return .toggleGroup
        case .url:
            guard let s = item.location, case .success(let url) = FavoriteURL.validate(s) else { return .missing }
            return .openWeb(url)
        case .app: return resolved.map(FavoriteAction.launchApp) ?? .missing
        case .file: return resolved.map(FavoriteAction.openFile) ?? .missing
        case .folder: return resolved.map(FavoriteAction.revealFolder) ?? .missing
        }
    }

    /// 열고 나서 서랍을 닫는지(다른 앱에 초점을 넘김). 묶음·못 찾음은 닫지 않는다.
    var closesDrawer: Bool {
        switch self {
        case .toggleGroup, .missing, .nothing: false
        default: true
        }
    }
}

/// 끌어다 놓거나 고른 위치의 종류: .app 꾸러미 = 앱, 폴더 = 폴더, 나머지 = 파일
enum FavoriteClassifier {
    static func kind(path: String, isDirectory: Bool) -> FavoriteKind {
        if isDirectory { return (path as NSString).pathExtension.lowercased() == "app" ? .app : .folder }
        return .file
    }

    /// 보일 이름: 앱은 「.app」을 뗀다
    static func displayName(path: String, kind: FavoriteKind) -> String {
        let last = (path as NSString).lastPathComponent
        return kind == .app ? (last as NSString).deletingPathExtension : last
    }
}


/// 수정 모드(즐겨찾기 「추가」 ~ 「저장」)의 규칙
enum FavoritesEditRules {
    enum EscResult: Equatable, Sendable { case closeInnermostColumn, nothing, closeDrawer }

    /// 바깥을 눌렀을 때 서랍을 닫는지
    static func autoCloses(editing: Bool, closeMode: CloseMode) -> Bool {
        !editing && closeMode == .outsideOrEsc
    }

    /// esc: 폴더 창이 있으면 가장 안쪽부터, 없으면 수정 중엔 아무 일 없음, 아니면 서랍 닫기
    static func esc(editing: Bool, openColumns: Int) -> EscResult {
        if openColumns > 0 { return .closeInnermostColumn }
        return editing ? .nothing : .closeDrawer
    }

    /// 수정 중 항목을 누르면 앱·파일·웹 주소는 열지 않는다(폴더 창 열고 닫기만).
    static func opensOnTap(_ action: FavoriteAction, editing: Bool) -> Bool {
        !editing || action == .toggleGroup
    }

    /// 다음 상태: 서랍이 닫히거나 탭이 바뀌면 끝난다.
    enum Event: Sendable { case tapAdd, tapSave, drawerClosed, tabChanged }
    static func next(_ editing: Bool, _ event: Event) -> Bool {
        switch event {
        case .tapAdd: true
        case .tapSave, .drawerClosed, .tabChanged: false
        }
    }
}

extension Layout {
    /// 점이 창들(서랍·폴더 창) 중 하나 안에 있는지. 창 사이 틈(6pt)을 지날 때 닫히지 않게 margin만큼 넓혀 본다.
    static func isInside(_ point: CGPoint, frames: [CGRect], margin: CGFloat) -> Bool {
        frames.contains { $0.insetBy(dx: -margin, dy: -margin).contains(point) }
    }

    /// 즐겨찾기를 연 뒤 「실행 후 유지」: 마우스가 창들 밖에 dwell초 이상 머물면 닫는다(틈을 지나는 잠깐은 유지).
    struct LeaveTracker: Sendable {
        var dwell: Double = 0.4
        private(set) var outsideSince: Double?

        init(dwell: Double = 0.4) { self.dwell = dwell }

        /// now: 초. 닫아야 하면 true.
        mutating func update(inside: Bool, now: Double) -> Bool {
            if inside { outsideSince = nil; return false }
            if let since = outsideSince { return now - since >= dwell - 0.001 }   // 소수 오차 허용
            outsideSince = now
            return false
        }
    }

    /// 수정 모드의 폴더 창 폭: 단추 줄·손잡이가 들어가도록 넓힌다(글자 크기·창 크기에 맞춤).
    static func listWindowWidth(editing: Bool, scale: CGFloat, text: CGFloat) -> CGFloat {
        let base = listWindowWidth * scale
        guard editing else { return base }
        // 아이콘 단추 4개 + 손잡이 + 여백을 넣을 최소 폭
        let needed = (4 * 26 + 3 * 4 + 24) * text + 40 * scale
        return max(base, needed, 196 * max(scale, text))
    }

    /// 목록 창 높이: 제목 + 고정 줄(맨 위 단추·입력 줄) + 항목 목록. 450을 넘으면 450(항목 목록만 스크롤).
    static func listWindowHeight(fixed: CGFloat, items: CGFloat) -> CGFloat {
        min(listWindowPadding * 2 + listWindowHeader + max(fixed, 0) + max(items, 0) + 4, listWindowMaxHeight)
    }
}


/// 끌어다 놓은 것이 무엇인지: 서랍 안 줄 옮기기(앱 전용 형식)인지, 밖에서 온 파일·주소인지
enum FavoriteDrop {
    static let reorderType = "local.toptiroir.favorite"

    enum Kind: Equatable, Sendable { case reorder, external, none }

    /// 줄 위에 놓을 때 자리: 위쪽 = 앞에, 아래쪽 = 뒤에, 폴더 줄 가운데 = 그 폴더 안에
    enum Zone: Equatable, Sendable { case before, after, into }

    /// y: 줄 안에서 위에서부터 잰 위치
    static func zone(y: Double, height: Double, isFolder: Bool) -> Zone {
        guard height > 0 else { return .after }
        let r = y / height
        if isFolder {
            if r < 0.25 { return .before }
            if r > 0.75 { return .after }
            return .into
        }
        return r < 0.5 ? .before : .after
    }

    /// 앱 전용 형식이 있으면 무조건 옮기기(파일·주소로 해석하지 않음)
    static func classify(typeIdentifiers: [String]) -> Kind {
        if typeIdentifiers.contains(reorderType) { return .reorder }
        if typeIdentifiers.contains(where: { $0 == "public.file-url" || $0 == "public.url" }) { return .external }
        return .none
    }
}

/// 즐겨찾기 줄 오른쪽 클릭 메뉴(순서는 끌어서 바꾸므로 위로/아래로 없음)
enum FavoriteMenu {
    static let rename = "이름 바꾸기"
    static let remove = "즐겨찾기에서 삭제"
    static let removeSeparator = "삭제"
    static func items(for kind: FavoriteKind) -> [String] {
        kind == .separator ? [removeSeparator] : [rename, remove]
    }
    static var items: [String] { items(for: .file) }
}


/// 진단 기록에 쓰는 종류 이름
enum FavoriteKindName {
    static func of(_ kind: FavoriteKind) -> String {
        switch kind {
        case .group: "폴더"
        case .app: "앱"
        case .file: "파일"
        case .url: "URL"
        case .folder: "Finder 폴더"
        case .separator: "구분선"
        }
    }
}
