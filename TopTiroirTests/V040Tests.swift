import CoreGraphics
import Foundation
import Testing

/// v0.4.0: 즐겨찾기 목록 모델·주소 검사·목록 창 높이·위치·단계 규칙·파일
struct FavoritesDocumentTests {
    func file(_ path: String, kind: FavoriteKind = .file) -> FavoriteItem {
        FavoriteItem(kind: kind, name: (path as NSString).lastPathComponent, location: path)
    }

    @Test func addNestedAndFind() {
        var d = FavoritesDocument()
        let g = UUID(), inner = UUID()
        let r1 = d.add(.group("개발", id: g), at: [])
        #expect(r1 == .added)
        let r2 = d.add(.group("안쪽", id: inner), at: [g])
        #expect(r2 == .added)
        let r3 = d.add(file("/tmp/a.txt"), at: [g, inner])
        #expect(r3 == .added)
        #expect(d.list(at: [g, inner])?.count == 1)
        #expect(d.find(inner)?.name == "안쪽")
        #expect(d.items.first?.descendantCount == 2)
        let r4 = d.add(file("/tmp/b.txt"), at: [UUID()])
        #expect(r4 == .noSuchGroup)
    }

    @Test func duplicatesRejectedInSameList() {
        var d = FavoritesDocument()
        let r5 = d.add(file("/Applications/Safari.app", kind: .app), at: [])
        #expect(r5 == .added)
        let r6 = d.add(file("/Applications/Safari.app", kind: .app), at: []) == .duplicate("Safari.app")
        #expect(r6)
        let r7 = d.add(.group("자료"), at: [])
        #expect(r7 == .added)
        let r8 = d.add(.group("자료"), at: []) == .duplicate("자료")
        #expect(r8)
        let g = d.items[1].id
        let r9 = d.add(file("/Applications/Safari.app", kind: .app), at: [g])
        #expect(r9 == .added) // 다른 위치는 괜찮음
        let u = FavoriteItem(kind: .url, name: "예시", location: "https://Example.com")
        let r10 = d.add(u, at: [])
        #expect(r10 == .added)
        let r11 = d.add(FavoriteItem(kind: .url, name: "다른 이름", location: "https://example.com"), at: []) == .duplicate("예시")
        #expect(r11)
    }

    @Test func renameMoveRemove() {
        var d = FavoritesDocument()
        let a = file("/tmp/a"), b = file("/tmp/b"), c = file("/tmp/c")
        [a, b, c].forEach { d.add($0, at: []) }
        let r12 = d.rename(b.id, to: "  새 이름 ", at: [])
        #expect(r12)
        let r13 = d.rename(b.id, to: "   ", at: [])
        #expect(!r13)
        #expect(d.item(b.id, at: [])?.name == "새 이름")
        let r14 = d.move(c.id, by: -1, at: [])
        #expect(r14)
        #expect(d.items.map(\.id) == [a.id, c.id, b.id])
        let r15 = d.move(a.id, by: -1, at: [])
        #expect(!r15)      // 맨 위에서 더 위로는 안 됨
        let r16 = d.remove(c.id, at: [])
        #expect(r16)
        let r17 = d.remove(c.id, at: [])
        #expect(!r17)
        #expect(d.items.map(\.id) == [a.id, b.id])
    }

    @Test func fileRoundTripAndBrokenFile() throws {
        var d = FavoritesDocument()
        let g = UUID()
        d.add(.group("묶음", id: g), at: [])
        d.add(FavoriteItem(kind: .file, name: "a", bookmark: Data([1, 2, 3]), location: "/tmp/a"), at: [g])
        #expect(FavoritesDocument.decode(try d.encoded()) == d)
        #expect(FavoritesDocument.decode(Data(#"{"version":1}"#.utf8)) == FavoritesDocument())   // 예전·빈 파일
        #expect(FavoritesDocument.decode(Data("망가짐".utf8)) == nil)
    }
}

struct FavoriteURLTests {
    @Test func accepts() {
        #expect((try? FavoriteURL.validate("https://example.com/a?b=1").get())?.absoluteString == "https://example.com/a?b=1")
        #expect((try? FavoriteURL.validate(" example.com ").get())?.absoluteString == "https://example.com")
        #expect((try? FavoriteURL.validate("http://localhost:8080").get()) != nil)
    }

    @Test func rejects() {
        #expect(FavoriteURL.validate("") == .failure(.empty))
        #expect(FavoriteURL.validate("https://exa mple.com") == .failure(.spaces))
        #expect(FavoriteURL.validate("file:///etc/passwd") == .failure(.scheme))
        #expect(FavoriteURL.validate("ftp://example.com") == .failure(.scheme))
        #expect(FavoriteURL.validate("javascript:alert(1)") == .failure(.scheme))
        #expect(FavoriteURL.validate("myapp://open") == .failure(.scheme))
        #expect(FavoriteURL.validate("그냥글자") == .failure(.invalid))
        #expect(FavoriteURL.defaultName(for: URL(string: "https://www.apple.com/kr")!) == "apple.com")
    }
}

struct FavoriteColumnTests {
    let a = UUID(), b = UUID(), c = UUID(), d = UUID()

    @Test func openReplaceClose() {
        var s = FavoriteColumns.toggle(a, fromLevel: 0, stack: [])
        #expect(s == [a])
        s = FavoriteColumns.toggle(b, fromLevel: 1, stack: s)          // 첫째 칸 안 묶음 → 둘째 칸
        #expect(s == [a, b])
        s = FavoriteColumns.toggle(c, fromLevel: 0, stack: s)          // 서랍에서 다른 묶음 → 교체
        #expect(s == [c])
        s = FavoriteColumns.toggle(c, fromLevel: 0, stack: s)          // 같은 묶음 다시 → 닫기
        #expect(s == [])
    }

    @Test func atMostThree() {
        #expect(FavoriteColumns.toggle(d, fromLevel: 3, stack: [a, b, c]) == [a, b, c])   // 넷째 칸은 없음
        #expect(FavoriteColumns.toggle(b, fromLevel: 1, stack: [a, b, c]) == [a])         // 둘째 칸 폴더 다시 → 그 뒤 닫힘
    }
}

struct ListWindowLayoutTests {
    let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)

    @Test func heightFollowsItemsUpTo450() {
        let h3 = Layout.listWindowHeight(itemCount: 3)
        #expect(h3 == 131, "높이 \(h3)")
        #expect(Layout.listWindowHeight(itemCount: 0) == Layout.listWindowHeight(itemCount: 1))
        #expect(Layout.listWindowHeight(itemCount: 100) == 450)
    }

    @Test func rightThenFlipLeft() {
        let drawer = CGRect(x: 645, y: 500, width: 420, height: 575)
        let f = Layout.listWindowFrame(after: drawer, height: 130, screenFrame: screen)
        #expect(f == CGRect(x: 1071, y: 945, width: 168, height: 130))
        let edge = CGRect(x: 1500, y: 500, width: 200, height: 575)
        #expect(Layout.listWindowFrame(after: edge, height: 130, screenFrame: screen).maxX == 1494)
    }
}

struct FavoriteActionTests {
    @Test func decideWhatToDo() {
        let app = FavoriteItem(kind: .app, name: "Safari", location: "/Applications/Safari.app")
        let u = URL(fileURLWithPath: "/Applications/Safari.app")
        #expect(FavoriteAction.decide(app, resolved: u) == .launchApp(u))
        #expect(FavoriteAction.decide(app, resolved: nil) == .missing)         // 북마크가 깨짐 → 찾을 수 없어요
        let web = FavoriteItem(kind: .url, name: "예", location: "https://example.com")
        #expect(FavoriteAction.decide(web, resolved: nil) == .openWeb(URL(string: "https://example.com")!))
        let bad = FavoriteItem(kind: .url, name: "나쁨", location: "file:///etc")
        #expect(FavoriteAction.decide(bad, resolved: nil) == .missing)        // 저장 파일이 고쳐져도 http(s)만
        #expect(FavoriteAction.decide(.group("묶음"), resolved: nil) == .toggleGroup)
        #expect(FavoriteAction.launchApp(u).closesDrawer && !FavoriteAction.toggleGroup.closesDrawer && !FavoriteAction.missing.closesDrawer)
    }

    @Test func classify() {
        #expect(FavoriteClassifier.kind(path: "/Applications/Notes.app", isDirectory: true) == .app)
        #expect(FavoriteClassifier.kind(path: "/tmp/자료", isDirectory: true) == .folder)
        #expect(FavoriteClassifier.kind(path: "/tmp/a.pdf", isDirectory: false) == .file)
        #expect(FavoriteClassifier.displayName(path: "/Applications/Notes.app", kind: .app) == "Notes")
        #expect(FavoriteClassifier.displayName(path: "/tmp/a.pdf", kind: .file) == "a.pdf")
    }
}


struct FavoritesRevisionTests {
    func file(_ n: String) -> FavoriteItem { FavoriteItem(kind: .file, name: n, location: "/tmp/" + n) }

    @Test func folderDepthLimitedToThree() {
        var d = FavoritesDocument()
        let a = UUID(), b = UUID(), c = UUID()
        let r1 = d.add(.group("1단계", id: a), at: [])
        let r2 = d.add(.group("2단계", id: b), at: [a])
        let r3 = d.add(.group("3단계", id: c), at: [a, b])
        let r4 = d.add(.group("4단계"), at: [a, b, c])
        let r5 = d.add(file("x"), at: [a, b, c])          // 3단계 폴더 안에도 파일은 넣을 수 있음
        #expect(r1 == .added && r2 == .added && r3 == .added)
        #expect(r4 == .tooDeep && r5 == .added)
        #expect(FavoritesDocument.canAddGroup(at: [a, b]) && !FavoritesDocument.canAddGroup(at: [a, b, c]))
    }

    @Test func dragReorder() {
        var d = FavoritesDocument()
        let items = ["a", "b", "c", "d"].map(file)
        items.forEach { d.add($0, at: []) }
        let ids = items.map(\.id)
        let m1 = d.move(ids[0], before: ids[2], at: [])     // a를 c 자리로(아래로) → b c a d
        #expect(m1)
        #expect(d.items.map(\.name) == ["b", "c", "a", "d"])
        let m2 = d.move(ids[3], before: ids[1], at: [])     // d를 b 자리로(위로) → d b c a
        #expect(m2)
        #expect(d.items.map(\.name) == ["d", "b", "c", "a"])
        let m3 = d.move(ids[1], before: nil, at: [])        // 맨 끝으로
        #expect(m3 && d.items.last?.name == "b")
        let m4 = d.move(ids[0], before: UUID(), at: [])     // 다른 목록의 줄 위 → 안 바꿈
        #expect(!m4)
    }
}


struct FavoritesMoveTests {
    func file(_ n: String) -> FavoriteItem { FavoriteItem(kind: .file, name: n, location: "/tmp/" + n) }

    @Test func relocateAcrossListsWithDepthCheck() {
        var d = FavoritesDocument()
        let a = UUID(), b = UUID(), c = UUID(), x = UUID(), y = UUID()
        d.add(.group("A", id: a), at: [])
        d.add(.group("B", id: b), at: [a])
        d.add(.group("C", id: c), at: [a, b])          // 3단계
        d.add(.group("X", id: x), at: [])
        d.add(.group("Y", id: y), at: [x])             // X 깊이 2
        let f = file("f")
        d.add(f, at: [])
        let r1 = d.relocate(f.id, to: [a, b, c], before: nil)      // 파일은 3단계 폴더 안으로 가능
        #expect(r1 == .moved && d.list(at: [a, b, c])?.count == 1)
        let r2 = d.relocate(x, to: [a, b], before: nil)            // 2단계 목록 + 깊이 2 = 4 → 막음
        #expect(r2 == .tooDeep)
        let r3 = d.relocate(x, to: [a], before: nil)               // 1 + 2 = 3 → 가능
        #expect(r3 == .moved && d.list(at: [a])?.contains { $0.id == x } == true)
        let r4 = d.relocate(a, to: [a, b], before: nil)            // 자기 안으로
        #expect(r4 == .intoItself)
        #expect(d.items.first?.groupDepth == 3)
    }

    @Test func flattenOldDeepFolders() {
        // 예전에 만들어진 5단계: A > B > C > D > E
        let e = FavoriteItem.group("E")
        let dd = FavoriteItem.group("D", children: [e])
        let c = FavoriteItem.group("C", children: [dd])
        let b = FavoriteItem.group("B", children: [c])
        let a = FavoriteItem.group("A", children: [b])
        var doc = FavoritesDocument(items: [a])
        let moved = doc.flattenTooDeep()
        #expect(moved == 2)                                     // D, E를 끌어올림
        #expect(doc.items.allSatisfy { $0.groupDepth <= 3 })
        #expect(doc.list(at: [a.id, b.id])?.map(\.name) == ["C", "D", "E"])
        #expect(doc.find(e.id) != nil)                          // 지우지 않음
    }
}

struct FavoritesEditRuleTests {
    @Test func autoCloseStopsWhileEditing() {
        #expect(FavoritesEditRules.autoCloses(editing: false, closeMode: .outsideOrEsc))
        #expect(!FavoritesEditRules.autoCloses(editing: true, closeMode: .outsideOrEsc))
        #expect(!FavoritesEditRules.autoCloses(editing: false, closeMode: .escOnly))
    }

    @Test func escRules() {
        #expect(FavoritesEditRules.esc(editing: true, openColumns: 2) == .closeInnermostColumn)
        #expect(FavoritesEditRules.esc(editing: true, openColumns: 0) == .nothing)
        #expect(FavoritesEditRules.esc(editing: false, openColumns: 0) == .closeDrawer)
    }

    @Test func tapWhileEditing() {
        let u = URL(fileURLWithPath: "/Applications/Safari.app")
        #expect(!FavoritesEditRules.opensOnTap(.launchApp(u), editing: true))
        #expect(FavoritesEditRules.opensOnTap(.toggleGroup, editing: true))
        #expect(FavoritesEditRules.opensOnTap(.launchApp(u), editing: false))
    }

    @Test func stateTransitions() {
        #expect(FavoritesEditRules.next(false, .tapAdd))
        #expect(!FavoritesEditRules.next(true, .tapSave))
        #expect(!FavoritesEditRules.next(true, .drawerClosed))
        #expect(!FavoritesEditRules.next(true, .tabChanged))
    }

    @Test func heightWithInsertedRows() {
        let h = Layout.listWindowHeight(fixed: 24, items: 72)
        #expect(h == 134, "\(h)")
        #expect(Layout.listWindowHeight(fixed: 120, items: 900) == 450)
    }
}


struct FavoriteDropTests {
    @Test func ownRowDragIsNeverReadAsURL() {
        // 서랍 안 줄 끌기: 앱 전용 형식만 → 옮기기(웹 주소 안내가 뜨지 않음)
        #expect(FavoriteDrop.classify(typeIdentifiers: ["local.toptiroir.favorite"]) == .reorder)
        #expect(FavoriteDrop.classify(typeIdentifiers: ["local.toptiroir.favorite", "public.url"]) == .reorder)
        #expect(FavoriteDrop.classify(typeIdentifiers: ["public.file-url"]) == .external)
        #expect(FavoriteDrop.classify(typeIdentifiers: ["public.url"]) == .external)
        #expect(FavoriteDrop.classify(typeIdentifiers: ["public.plain-text"]) == .none)
    }

    @Test func contextMenuHasTwoItems() {
        #expect(FavoriteMenu.items == ["이름 바꾸기", "즐겨찾기에서 삭제"])
    }
}


struct FavoriteSeparatorAndZoneTests {
    @Test func separators() {
        var d = FavoritesDocument()
        let r1 = d.add(.separator(), at: [])
        let r2 = d.add(.separator(), at: [])          // 여러 개 가능
        #expect(r1 == .added && r2 == .added && d.items.count == 2)
        #expect(FavoriteAction.decide(.separator(), resolved: nil) == .nothing)
        #expect(!FavoriteAction.nothing.closesDrawer)
        #expect(FavoriteMenu.items(for: .separator) == ["삭제"])
        let g = FavoriteItem.group("폴더", children: [.separator(), FavoriteItem(kind: .file, name: "a", location: "/a")])
        #expect(g.visibleChildCount == 1)                 // 제목 개수에서 구분선 제외
        #expect(FavoritesDocument.decode(try! d.encoded())?.items.map(\.kind) == [.separator, .separator])
    }

    @Test func dropZones() {
        #expect(FavoriteDrop.zone(y: 3, height: 24, isFolder: false) == .before)
        #expect(FavoriteDrop.zone(y: 20, height: 24, isFolder: false) == .after)
        #expect(FavoriteDrop.zone(y: 3, height: 24, isFolder: true) == .before)
        #expect(FavoriteDrop.zone(y: 12, height: 24, isFolder: true) == .into)    // 폴더 가운데만 안으로
        #expect(FavoriteDrop.zone(y: 22, height: 24, isFolder: true) == .after)
    }
}


struct EditWidthTests {
    @Test func widerWhileEditing() {
        #expect(Layout.listWindowWidth(editing: false, scale: 1, text: 1) == 168)
        #expect(Layout.listWindowWidth(editing: true, scale: 1, text: 1) >= 196)
        #expect(Layout.listWindowWidth(editing: true, scale: 1, text: 1.4) > Layout.listWindowWidth(editing: true, scale: 1, text: 1))
    }

    @Test func oldFileWithoutSeparatorsStillLoads() {
        let old = Data(#"{"version":1,"items":[{"id":"8D9C5B7E-1111-4C2E-9A00-000000000001","kind":"group","name":"A","children":[]}]}"#.utf8)
        #expect(FavoritesDocument.decode(old)?.items.first?.name == "A")
    }
}


struct DiagnosticNameTests {
    @Test func kindNames() {
        #expect(FavoriteKindName.of(.app) == "앱")
        #expect(FavoriteKindName.of(.folder) == "Finder 폴더")
        #expect(FavoriteKindName.of(.group) == "폴더")
        // 수정 모드가 아닐 때만 앱이 열린다
        #expect(FavoritesEditRules.opensOnTap(.launchApp(URL(fileURLWithPath: "/a.app")), editing: false))
    }
}


struct MouseLeaveTests {
    @Test func staysOpenWhileInsideOrInGap() {
        let drawer = CGRect(x: 645, y: 500, width: 420, height: 575)
        let column = CGRect(x: 1071, y: 900, width: 168, height: 175)
        #expect(Layout.isInside(CGPoint(x: 700, y: 600), frames: [drawer, column], margin: 8))
        #expect(Layout.isInside(CGPoint(x: 1068, y: 950), frames: [drawer, column], margin: 8))   // 서랍과 폴더 창 사이 틈
        #expect(Layout.isInside(CGPoint(x: 1100, y: 950), frames: [drawer, column], margin: 8))
        #expect(!Layout.isInside(CGPoint(x: 300, y: 300), frames: [drawer, column], margin: 8))  // 나감 → 닫기
    }
}


struct LeaveTrackerTests {
    @Test func closesAfterDwellOutside() {
        var t = Layout.LeaveTracker()
        let u1 = t.update(inside: true, now: 0)
        #expect(!u1)
        let u2 = t.update(inside: false, now: 1.0)
        #expect(!u2)     // 막 나감
        let u3 = t.update(inside: false, now: 1.3)
        #expect(!u3)     // 0.3초
        let u4 = t.update(inside: false, now: 1.4)
        #expect(u4)      // 0.4초 → 닫기
    }

    @Test func comingBackResets() {
        var t = Layout.LeaveTracker()
        _ = t.update(inside: false, now: 0)
        let u5 = t.update(inside: false, now: 0.2)
        #expect(!u5)
        let u6 = t.update(inside: true, now: 0.3)
        #expect(!u6)      // 서랍→폴더 창 틈을 지나 다시 안으로
        let u7 = t.update(inside: false, now: 0.5)
        #expect(!u7)
        let u8 = t.update(inside: false, now: 0.8)
        #expect(!u8)     // 다시 잰 지 0.3초
        let u9 = t.update(inside: false, now: 0.9)
        #expect(u9)
    }
}
