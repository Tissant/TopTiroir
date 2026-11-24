import AppKit
import Observation
import os

private let favLog = Logger(subsystem: "local.toptiroir.app", category: "Favorites")

/// 항목 열기(시험에서는 가짜로 바꿔 끼울 수 있게). 끝나면 done(성공 여부)을 부른다.
@MainActor
protocol FavoriteOpening {
    func perform(_ action: FavoriteAction, done: @escaping @MainActor (Bool) -> Void)
}

/// 필요할 때만 켜는 열기 진단 기록(앱 지원 폴더의 debug-open.log).
/// 켜기: defaults write local.toptiroir.app debugOpenLog -bool true / 끄기: defaults delete local.toptiroir.app debugOpenLog
/// 경로·주소는 적지 않고 종류·번들 ID·단계·결과만.
@MainActor
enum DebugOpenLog {
    static var enabled: Bool { UserDefaults.standard.bool(forKey: "debugOpenLog") }
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func write(_ text: @autoclosure () -> String) {
        guard enabled else { return }   // 꺼져 있으면 아무것도 하지 않음
        let url = FavoritesStore.defaultFileURL.deletingLastPathComponent().appending(path: "debug-open.log")
        let line = "\(formatter.string(from: Date())) \(text())\n"
        guard let data = line.data(using: .utf8) else { return }
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(data); try? h.close()
        } else {
            try? data.write(to: url)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }
}

/// 실제로 여는 일: 사용자가 항목을 눌렀을 때만 부른다.
/// macOS 14부터는 활성이 아닌 앱이 다른 앱을 앞으로 가져오지 못한다(협력적 활성화).
/// 서랍은 앱을 활성으로 만들지 않으므로 ① TopTiroir를 활성으로 ② 열 앱에 활성을 넘겨줌(yield) ③ activates = true로 연다.
@MainActor
struct WorkspaceOpener: FavoriteOpening {
    func perform(_ action: FavoriteAction, done: @escaping @MainActor (Bool) -> Void) {
        let ws = NSWorkspace.shared
        let target: URL
        let kind: String
        switch action {
        case .launchApp(let url): target = url; kind = "앱"
        case .openFile(let url): target = url; kind = "파일"
        case .revealFolder(let url): target = url; kind = "폴더"
        case .openWeb(let url): target = url; kind = "URL"
        case .toggleGroup, .missing, .nothing: done(false); return
        }
        // 열 앱(앱이면 그 앱, 아니면 이 파일·주소를 여는 기본 앱)
        let appURL: URL? = {
            if case .launchApp(let u) = action { return u }
            return ws.urlForApplication(toOpen: target)
        }()
        let bundleID = appURL.flatMap { Bundle(url: $0)?.bundleIdentifier }
        DebugOpenLog.write("클릭 \(kind) 대상=\(bundleID ?? "-") 활성=\(NSApp.isActive)")
        NSApp.activate()
        if let bundleID { NSApp.yieldActivation(toApplicationWithBundleIdentifier: bundleID) }
        DebugOpenLog.write("활성화 요청 후 활성=\(NSApp.isActive)")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        let finish: @Sendable (NSRunningApplication?, Error?) -> Void = { app, error in
            let ok = error == nil
            let code = (error as NSError?)?.code ?? 0
            let pid = app?.processIdentifier
            Task { @MainActor in
                let running = pid.flatMap { NSRunningApplication(processIdentifier: $0) }
                DebugOpenLog.write("완료 \(ok ? "성공" : "오류 \(code)") 앞=\(running?.isActive == true)")
                if let error { favLog.error("열기 실패: \(error.localizedDescription, privacy: .public)") }
                guard ok else { done(false); return }
                await Self.bringForward(running, bundleID: bundleID)
                done(true)   // 열린 앱이 앞에 나온 걸 확인한 뒤(또는 기다린 뒤)에 서랍을 닫는다
            }
        }
        DebugOpenLog.write("open 호출")
        if case .launchApp = action {
            ws.openApplication(at: target, configuration: config, completionHandler: finish)
        } else {
            ws.open(target, configuration: config, completionHandler: finish)
        }
    }
}

extension WorkspaceOpener {
    /// 열린 앱이 실제로 맨 앞에 나왔는지 0.3초·1초에 확인하고, 일반 앱인데 안 나왔으면 한 번 더 앞으로.
    /// 창 없는 메뉴막대 앱(accessory)은 원래 앞으로 나오지 않으므로 실패로 보지 않는다.
    static func bringForward(_ app: NSRunningApplication?, bundleID: String?) async {
        func state(_ when: String) {
            let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "-"
            let policy: String = switch app?.activationPolicy {
            case .regular: "regular"
            case .accessory: "accessory(창 없는 앱)"
            case .prohibited: "prohibited"
            default: "-"
            }
            DebugOpenLog.write("\(when) 맨 앞=\(front) 대상 실행=\(app.map { !$0.isTerminated } ?? false) 숨김=\(app?.isHidden == true) 종류=\(policy) 뜸=\(app?.isFinishedLaunching == true)")
        }
        // 메뉴막대 전용(창 없는) 앱: 앞으로 나오지 않는 게 정상
        if let app, app.activationPolicy != .regular {
            DebugOpenLog.write("창 없는 앱(앞으로 나오지 않음)")
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        state("0.3초 뒤")
        if let app, !app.isActive {
            if app.isHidden { app.unhide() }
            let again = app.activate(options: [.activateAllWindows])
            DebugOpenLog.write("다시 앞으로 요청=\(again)")
        }
        guard DebugOpenLog.enabled else { return }
        try? await Task.sleep(for: .milliseconds(700))
        state("1초 뒤")
    }
}

/// 즐겨찾기 목록: 앱 지원 폴더의 favorites.json(내 계정만). 위치는 북마크로 저장하고 파일은 복사하지 않는다.
@MainActor
@Observable
final class FavoritesStore {
    private(set) var document = FavoritesDocument()
    /// 한 줄 안내(찾을 수 없어요·중복·주소 오류 등). 잠시 뒤 사라짐.
    var notice: String?
    /// 안내를 보일 창(0 = 서랍, 1~3 = 폴더 창). 같은 안내가 여러 창에 겹쳐 뜨지 않게.
    var noticeLevel = 0
    /// 북마크로 찾지 못한 항목
    private(set) var missing: Set<UUID> = []

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let opener: FavoriteOpening
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var noticeTask: Task<Void, Never>?
    @ObservationIgnored private var dirty = false
    @ObservationIgnored private var saveBlocked = false
    /// 내용이 바뀔 때(목록 창 높이 다시 계산)
    @ObservationIgnored var onChange: (() -> Void)?

    init(fileURL: URL = FavoritesStore.defaultFileURL, opener: FavoriteOpening = WorkspaceOpener()) {
        self.fileURL = fileURL
        self.opener = opener
        load()
        refreshMissing()
    }

    static var defaultFileURL: URL {
        NotesStore.defaultFileURL.deletingLastPathComponent().appending(path: "favorites.json")
    }
    var backupFileURL: URL { fileURL.deletingLastPathComponent().appending(path: "favorites.backup.json") }

    // MARK: 추가

    /// 고르거나 끌어다 놓은 위치들(파일 위치 또는 웹 주소)
    func add(urls: [URL], at path: [UUID]) {
        var dups: [String] = [], bad: [String] = []
        for url in urls {
            let item: FavoriteItem
            if url.isFileURL {
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
                let kind = FavoriteClassifier.kind(path: url.path, isDirectory: isDir.boolValue)
                let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                item = FavoriteItem(kind: kind, name: FavoriteClassifier.displayName(path: url.path, kind: kind),
                                    bookmark: bookmark, location: url.path)
            } else {
                guard case .success(let web) = FavoriteURL.validate(url.absoluteString) else { bad.append(url.absoluteString); continue }
                item = FavoriteItem(kind: .url, name: FavoriteURL.defaultName(for: web), location: web.absoluteString)
            }
            switch document.add(item, at: path) {
            case .duplicate(let name): dups.append(name)
            default: break
            }
        }
        changed()
        if !dups.isEmpty { say("이미 있어요: \(dups.joined(separator: ", "))") }
        else if !bad.isEmpty { say(FavoriteURL.message(.scheme)) }
    }

    /// 웹 주소 추가. 문제가 있으면 안내 글.
    func addWeb(name: String, address: String, at path: [UUID]) -> String? {
        switch FavoriteURL.validate(address) {
        case .failure(let p): return FavoriteURL.message(p)
        case .success(let url):
            let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let item = FavoriteItem(kind: .url, name: n.isEmpty ? FavoriteURL.defaultName(for: url) : n,
                                    location: url.absoluteString)
            if case .duplicate(let d) = document.add(item, at: path) { return "이미 있어요: \(d)" }
            changed()
            return nil
        }
    }

    static let tooDeepMessage = "폴더는 3단계까지만 만들 수 있어요."

    func addGroup(name: String, at path: [UUID]) -> String? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return "폴더 이름을 적어 주세요." }
        switch document.add(.group(n), at: path) {
        case .duplicate(let d): return "같은 이름의 폴더가 있어요: \(d)"
        case .tooDeep: return Self.tooDeepMessage
        case .noSuchGroup: return "폴더를 찾을 수 없어요."
        case .added:
            changed()
            return nil
        }
    }

    /// 목록 구분선(맨 끝에 넣고 끌어서 옮김)
    func addSeparator(at path: [UUID]) {
        document.add(.separator(), at: path)
        changed()
    }

    // MARK: 정리 (목록에서만, 실제 파일은 건드리지 않음)

    func remove(_ id: UUID, at path: [UUID]) {
        backup()
        document.remove(id, at: path)
        changed()
    }

    func rename(_ id: UUID, to name: String, at path: [UUID]) {
        guard let old = document.item(id, at: path), old.name != name.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        backup()
        document.rename(id, to: name, at: path)
        changed()
    }

    func move(_ id: UUID, by offset: Int, at path: [UUID]) {
        if document.move(id, by: offset, at: path) { changed() }
    }

    /// 끌어서 옮기기(같은 목록 안 순서, 다른 목록·폴더 안으로). 직전 상태를 백업.
    func relocate(_ id: UUID, to target: [UUID], before: UUID?) {
        var copy = document
        switch copy.relocate(id, to: target, before: before) {
        case .moved:
            backup()
            document = copy
            changed()
        case .tooDeep: say(Self.tooDeepMessage)
        case .intoItself: say("폴더를 자기 안으로는 옮길 수 없어요.")
        case .duplicate(let name): say("그 폴더에 이미 있어요: \(name)")
        case .unchanged, .notFound: break
        }
    }

    // MARK: 앱 아이콘

    @ObservationIgnored private var iconCache: [String: NSImage] = [:]

    /// 앱 줄에 보일 실제 앱 아이콘. 필요한 크기(레티나 2배)로만 줄여서 캐시한다. 앱이 없으면 nil → 선 아이콘.
    func appIcon(_ item: FavoriteItem, size: CGFloat) -> NSImage? {
        guard item.kind == .app, !missing.contains(item.id) else { return nil }
        let key = "\(item.id.uuidString)-\(Int(size))"
        if let cached = iconCache[key] { return cached }
        guard let url = resolve(item) else { return nil }
        let full = NSWorkspace.shared.icon(forFile: url.path)
        let px = max(Int(size * 2), 16)
        let small = NSImage(size: NSSize(width: size, height: size))
        if let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0) {
            rep.size = NSSize(width: size, height: size)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSGraphicsContext.current?.imageInterpolation = .high
            full.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
            NSGraphicsContext.restoreGraphicsState()
            small.addRepresentation(rep)
        }
        iconCache[key] = small
        return small
    }

    // MARK: 열기

    /// 사용자가 누른 항목. 열기가 끝나면(완료 알림을 받은 뒤) opened를 부른다 — 서랍은 그때 닫는다.
    @discardableResult
    func activate(_ item: FavoriteItem, opened: @escaping @MainActor () -> Void = {}) -> FavoriteAction {
        let action = FavoriteAction.decide(item, resolved: resolve(item))
        if action == .missing {
            missing.insert(item.id)
            say("「\(item.name)」을(를) 찾을 수 없어요. 옮겨졌거나 지워졌을 수 있어요.")
        } else if action.closesDrawer {
            opener.perform(action) { _ in opened() }
        }
        return action
    }

    func isMissing(_ item: FavoriteItem) -> Bool { missing.contains(item.id) }

    /// 북마크로 지금 위치를 찾는다(옮겨졌으면 북마크를 새로 고침).
    func resolve(_ item: FavoriteItem) -> URL? {
        guard item.kind == .app || item.kind == .file || item.kind == .folder else { return nil }
        var url: URL?
        if let data = item.bookmark {
            var stale = false
            url = try? URL(resolvingBookmarkData: data, options: [.withoutUI, .withoutMounting],
                           relativeTo: nil, bookmarkDataIsStale: &stale)
            if stale, let u = url, let fresh = try? u.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                refreshBookmark(item.id, data: fresh, location: u.path)
            }
        }
        if url == nil, let p = item.location { url = URL(fileURLWithPath: p) }
        // 휴지통으로 간 것도 「찾을 수 없음」으로 본다(북마크는 휴지통까지 따라가므로).
        guard let found = url, FileManager.default.fileExists(atPath: found.path),
              !found.path.contains("/.Trash/") else { return nil }
        return found
    }

    /// 서랍을 열 때 흐리게 보일 항목을 다시 확인
    func refreshMissing() {
        var gone: Set<UUID> = []
        func walk(_ list: [FavoriteItem]) {
            for i in list {
                if i.kind == .group { walk(i.children ?? []) }
                else if i.kind != .url, i.kind != .separator, resolve(i) == nil { gone.insert(i.id) }
            }
        }
        walk(document.items)
        if gone != missing { missing = gone }
    }

    private func refreshBookmark(_ id: UUID, data: Data, location: String) {
        func walk(_ list: inout [FavoriteItem]) -> Bool {
            for k in list.indices {
                if list[k].id == id { list[k].bookmark = data; list[k].location = location; return true }
                if var c = list[k].children, walk(&c) { list[k].children = c; return true }
            }
            return false
        }
        var items = document.items
        if walk(&items) { document.items = items; scheduleSave() }
    }

    func say(_ text: String) {
        notice = text
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    // MARK: 저장 (입력이 멈추고 0.8초 뒤)

    private func changed() {
        scheduleSave()
        onChange?()
    }

    private func scheduleSave() {
        dirty = true
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        guard dirty, !saveBlocked else { return }
        do {
            try write(document, to: fileURL)
            dirty = false
        } catch {
            favLog.error("즐겨찾기 저장 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 지우기·이름 바꾸기 직전 상태를 favorites.backup.json 한 개로(덮어씀)
    @discardableResult
    private func backup() -> Bool {
        do {
            try write(document, to: backupFileURL)
            return true
        } catch {
            favLog.error("즐겨찾기 백업 실패: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: 가져오기 (설정 › 관리)

    /// 백업 파일의 즐겨찾기로 바꾼다. 바꾸기 직전 상태를 favorites.backup.json에 남기고, 백업에 실패하면 바꾸지 않는다.
    /// 3단계보다 깊은 폴더는 불러올 때와 같이 한 단계씩 끌어올린다.
    @discardableResult
    func replace(with doc: FavoritesDocument) -> Bool {
        guard !saveBlocked, backup() else { return false }
        var d = doc
        _ = d.flattenTooDeep()
        document = d
        refreshMissing()
        changed()
        saveNow()
        return true
    }

    private func write(_ doc: FavoritesDocument, to url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                               attributes: [.posixPermissions: 0o700])
        try doc.encoded().write(to: url, options: [.atomic])
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if var doc = FavoritesDocument.decode(data) {
            // 예전에 3단계보다 깊게 만든 폴더가 있으면 백업 후 끌어올린다(지우지 않음).
            let original = doc
            let moved = doc.flattenTooDeep()
            if moved > 0 {
                try? write(original, to: backupFileURL)
                document = doc
                dirty = true
                saveNow()
                notice = "폴더는 3단계까지라 더 깊은 폴더 \(moved)개를 한 단계 위로 옮겼어요. (이전 상태는 백업)"
                favLog.notice("3단계 초과 폴더 정리: \(moved)개")
            } else {
                document = doc
            }
            return
        }
        // 읽을 수 없는 파일은 지우지 않고 옆으로 옮긴다.
        let aside = fileURL.deletingLastPathComponent().appending(path: "favorites-읽기실패-\(Int(Date().timeIntervalSince1970)).json")
        if (try? FileManager.default.moveItem(at: fileURL, to: aside)) != nil {
            notice = "예전 즐겨찾기 파일을 읽지 못해 \(aside.lastPathComponent)로 보관했어요."
        } else {
            saveBlocked = true
            notice = "즐겨찾기 파일을 읽지 못했어요. 파일을 지키려고 저장하지 않아요."
        }
    }
}
