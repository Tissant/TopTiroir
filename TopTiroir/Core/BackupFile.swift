import Foundation

/// 메모·할 일·즐겨찾기를 파일 하나로 내보내고 가져온다(설정 › 관리).
/// 이 맥 안에서만 쓰는 파일이다. 네트워크로 보내지 않는다.
struct BackupFile: Codable, Equatable, Sendable {
    /// 다른 JSON 파일을 실수로 고르는 것을 막는 표시
    static let formatName = "TopTiroir-backup"
    /// 이 앱이 읽을 수 있는 가장 높은 판
    static let currentVersion = 1

    var format = BackupFile.formatName
    var version = BackupFile.currentVersion
    /// 내보낸 시각(ISO 8601)
    var exportedAt: Date
    /// 내보낸 앱 버전(안내용)
    var appVersion: String
    var notes: NotesDocument?
    var favorites: FavoritesDocument?

    init(exportedAt: Date, appVersion: String, notes: NotesDocument?, favorites: FavoritesDocument?) {
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.notes = notes
        self.favorites = favorites
    }

    enum Problem: Error, Equatable, Sendable {
        /// JSON이 아니거나 TopTiroir 백업 형식이 아님
        case notBackup
        /// 더 새 버전 앱이 만든 파일
        case newerVersion(Int)
        /// 메모·즐겨찾기 어느 것도 없음
        case empty

        var message: String {
            switch self {
            case .notBackup: "TopTiroir 백업 파일이 아니에요."
            case .newerVersion: "더 새 버전의 TopTiroir가 만든 파일이라 읽을 수 없어요. 앱을 업데이트해 주세요."
            case .empty: "백업 파일에 메모·즐겨찾기가 없어요."
            }
        }
    }

    // MARK: 파일 글자

    func encoded() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return try e.encode(self)
    }

    static func decode(_ data: Data) -> Result<BackupFile, Problem> {
        // 형식 표시와 판을 먼저 본다(판이 높으면 나머지 칸 모양이 다를 수 있음).
        struct Header: Decodable { var format: String?; var version: Int? }
        guard let header = try? JSONDecoder().decode(Header.self, from: data),
              header.format == formatName else { return .failure(.notBackup) }
        let version = header.version ?? 1
        guard version <= currentVersion else { return .failure(.newerVersion(version)) }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        guard let file = try? d.decode(BackupFile.self, from: data) else { return .failure(.notBackup) }
        guard file.notes != nil || file.favorites != nil else { return .failure(.empty) }
        return .success(file)
    }

    // MARK: 안내

    /// 저장 창에 미리 넣을 이름: TopTiroir-백업-2026-11-24.json (이 맥의 날짜)
    static func suggestedFileName(date: Date, timeZone: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "TopTiroir-백업-%04d-%02d-%02d.json", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// 즐겨찾기 항목 수(폴더 안 포함, 구분선 제외)
    static func favoriteCount(_ doc: FavoritesDocument) -> Int {
        func count(_ list: [FavoriteItem]) -> Int {
            list.reduce(0) { $0 + ($1.kind == .separator ? 0 : 1) + count($1.children ?? []) }
        }
        return count(doc.items)
    }

    /// 「메모 120자 · 할 일 3개」 / 「즐겨찾기 12개」
    static func summary(notes: NotesDocument?, favorites: FavoritesDocument?) -> String {
        var parts: [String] = []
        if let n = notes { parts.append("메모 \(n.memo.count)자 · 할 일 \(n.todos.count)개") }
        if let f = favorites { parts.append("즐겨찾기 \(favoriteCount(f))개") }
        return parts.isEmpty ? "내용 없음" : parts.joined(separator: " · ")
    }
}

/// 로그인 자동 실행을 새 위치로 다시 등록할지.
/// macOS는 자동 실행을 「등록할 때의 앱 위치」로 기억한다. 개발용 빌드(build 폴더)에서 켠 뒤
/// /Applications에 설치하면 옛 위치를 계속 가리키므로, 설치된 앱이 처음 켜질 때 한 번 다시 등록한다.
enum LoginItemPolicy {
    /// 설치된 앱(/Applications 안)만 다시 등록한다. 개발용 빌드는 등록 위치를 바꾸지 않는다.
    static func shouldReregister(enabled: Bool, registeredPath: String?, currentPath: String) -> Bool {
        guard enabled, isInstalled(currentPath) else { return false }
        return registeredPath != currentPath
    }

    static func isInstalled(_ path: String) -> Bool {
        path.hasPrefix("/Applications/")
    }
}
