import Foundation
import Testing

/// v0.5.0: 내보내기·가져오기 파일, 자동 실행 다시 등록 규칙
struct BackupFileTests {
    func sample() -> BackupFile {
        var notes = NotesDocument(memo: "안녕 메모")
        notes.addTodo("우유 사기")
        let favs = FavoritesDocument(items: [
            .group("개발", children: [FavoriteItem(kind: .url, name: "애플", location: "https://apple.com"), .separator()]),
            FavoriteItem(kind: .file, name: "a.txt", bookmark: Data([1, 2, 3]), location: "/tmp/a.txt"),
        ])
        return BackupFile(exportedAt: Date(timeIntervalSince1970: 1_800_000_000), appVersion: "0.5.0",
                          notes: notes, favorites: favs)
    }

    @Test func roundTrip() throws {
        let file = sample()
        let data = try file.encoded()
        guard case .success(let back) = BackupFile.decode(data) else { Issue.record("읽기 실패"); return }
        #expect(back == file)
        #expect(back.favorites?.items[1].bookmark == Data([1, 2, 3]))
    }

    @Test func rejectsOtherJSON() throws {
        // 앱의 notes.json·favorites.json을 고른 경우
        let notesJSON = try NotesDocument(memo: "x").encoded()
        #expect(BackupFile.decode(notesJSON) == .failure(.notBackup))
        #expect(BackupFile.decode(Data("not json".utf8)) == .failure(.notBackup))
        #expect(BackupFile.decode(Data(#"{"format":"Other","version":1}"#.utf8)) == .failure(.notBackup))
    }

    @Test func rejectsNewerVersion() {
        let json = #"{"format":"TopTiroir-backup","version":9,"exportedAt":"2026-11-24T00:00:00Z","appVersion":"9.0"}"#
        #expect(BackupFile.decode(Data(json.utf8)) == .failure(.newerVersion(9)))
    }

    @Test func rejectsEmpty() {
        let json = #"{"format":"TopTiroir-backup","version":1,"exportedAt":"2026-11-24T00:00:00Z","appVersion":"0.5.0"}"#
        #expect(BackupFile.decode(Data(json.utf8)) == .failure(.empty))
    }

    @Test func partialFileReads() {
        // 즐겨찾기만 든 파일도 읽힌다
        let json = #"{"format":"TopTiroir-backup","version":1,"exportedAt":"2026-11-24T00:00:00Z","appVersion":"0.5.0","favorites":{"version":1,"items":[]}}"#
        guard case .success(let f) = BackupFile.decode(Data(json.utf8)) else { Issue.record("읽기 실패"); return }
        #expect(f.notes == nil)
        #expect(f.favorites?.items.isEmpty == true)
    }

    @Test func fileNameAndSummary() {
        let seoul = TimeZone(identifier: "Asia/Seoul")!
        // 2026-11-24 23:30 UTC = 11월 25일 서울
        let d = Date(timeIntervalSince1970: 1_795_563_000)
        #expect(BackupFile.suggestedFileName(date: d, timeZone: seoul) == "TopTiroir-백업-2026-11-25.json")
        let s = sample()
        #expect(BackupFile.favoriteCount(s.favorites!) == 3)   // 폴더 1 + 웹 주소 1 + 파일 1 (구분선 제외)
        #expect(BackupFile.summary(notes: s.notes, favorites: s.favorites) == "메모 5자 · 할 일 1개 · 즐겨찾기 3개")
        #expect(BackupFile.summary(notes: nil, favorites: nil) == "내용 없음")
    }
}

struct LoginItemPolicyTests {
    @Test func reregisterOnlyInstalledAndMoved() {
        let installed = "/Applications/TopTiroir.app"
        let debug = "/tmp/dev/build/Build/Products/Debug/TopTiroir.app"
        // 개발 빌드에서 켠 뒤 설치: 다시 등록
        #expect(LoginItemPolicy.shouldReregister(enabled: true, registeredPath: nil, currentPath: installed))
        #expect(LoginItemPolicy.shouldReregister(enabled: true, registeredPath: debug, currentPath: installed))
        // 이미 같은 위치: 그대로
        #expect(!LoginItemPolicy.shouldReregister(enabled: true, registeredPath: installed, currentPath: installed))
        // 꺼져 있음: 그대로
        #expect(!LoginItemPolicy.shouldReregister(enabled: false, registeredPath: debug, currentPath: installed))
        // 개발 빌드는 등록 위치를 바꾸지 않음
        #expect(!LoginItemPolicy.shouldReregister(enabled: true, registeredPath: installed, currentPath: debug))
    }
}

struct CenteredOriginTests {
    @Test func centersInSecondDisplay() {
        // 오른쪽에 놓인 외장 화면(원점이 0이 아님)에서도 그 화면 안에 놓인다
        let visible = CGRect(x: 1512, y: -200, width: 1920, height: 1080)
        let o = Layout.centeredOrigin(size: CGSize(width: 600, height: 400), in: visible)
        #expect(o.x == visible.midX - 300)
        #expect(visible.contains(CGRect(origin: o, size: CGSize(width: 600, height: 400))))
    }

    @Test func clampsWhenLargerThanScreen() {
        let visible = CGRect(x: 0, y: 0, width: 800, height: 500)
        let o = Layout.centeredOrigin(size: CGSize(width: 900, height: 600), in: visible)
        #expect(o.x == 0 && o.y == 0)
    }
}
