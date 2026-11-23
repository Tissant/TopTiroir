import CoreGraphics
import Testing

/// v0.2.2: 단축키 묶음(기본값·검사·충돌·탭 이동·저장)
struct ShortcutSetTests {
    typealias M = Shortcut.Modifier
    let set = ShortcutSet.defaults

    @Test func defaults() {
        #expect(set[.openDrawer] == .f12)
        #expect(set[.tabNotes].displayName == "F1")
        #expect(set[.tabFavorites].displayName == "F2")
        #expect(set[.tabSettings].displayName == "F3")
        #expect(set[.quit].displayName == "⌘Q")
        #expect(set.isAllDefault)
    }

    @Test func functionTabKeysWorkWithOrWithoutCursor() {
        #expect(set.localAction(keyCode: 122, modifiers: 0, textFocused: false) == .showTab(.notes))
        #expect(set.localAction(keyCode: 120, modifiers: 0, textFocused: true) == .showTab(.favorites))
        #expect(set.localAction(keyCode: 99, modifiers: 0, textFocused: true) == .showTab(.settings))
        #expect(set.localAction(keyCode: 18, modifiers: 0, textFocused: false) == nil)   // 1은 이제 기본 아님
    }

    @Test func singleCharacterKeyOnlyWithoutCursor() {
        var s = set
        s[.tabNotes] = Shortcut(keyCode: 18, modifiers: 0)                            // 사용자가 1로 바꿈
        #expect(s.localAction(keyCode: 18, modifiers: 0, textFocused: false) == .showTab(.notes))
        #expect(s.localAction(keyCode: 18, modifiers: 0, textFocused: true) == nil)   // 입력칸이면 글자로
        #expect(s.localAction(keyCode: 83, modifiers: 0, textFocused: false) == .showTab(.notes)) // 키패드 1
        s[.tabSettings] = Shortcut(keyCode: 20, modifiers: M.command)                 // ⌘3은 커서 있어도
        #expect(s.localAction(keyCode: 20, modifiers: M.command, textFocused: true) == .showTab(.settings))
    }

    @Test func migrateOldDefaults() {
        #expect(ShortcutSet.isOldTabDefault(Shortcut(keyCode: 18, modifiers: 0), for: .tabNotes))
        #expect(!ShortcutSet.isOldTabDefault(Shortcut(keyCode: 19, modifiers: 0), for: .tabNotes)) // 직접 바꾼 값
        #expect(!ShortcutSet.isOldTabDefault(Shortcut(keyCode: 21, modifiers: 0), for: .tabNotes))
        #expect(!ShortcutSet.isOldTabDefault(Shortcut(keyCode: 12, modifiers: M.command), for: .quit))
    }

    @Test func quitWorksEvenWithCursor() {
        #expect(set.localAction(keyCode: 12, modifiers: M.command, textFocused: true) == .quit)
        #expect(set.localAction(keyCode: 12, modifiers: 0, textFocused: false) == nil) // Q만
    }

    @Test func checks() {
        let q = Shortcut(keyCode: 12, modifiers: 0)
        #expect(set.check(Shortcut(keyCode: 53, modifiers: 0), for: .tabNotes) == .cancel)
        #expect(set.check(Shortcut(keyCode: 21, modifiers: 0), for: .tabNotes) == .ok)              // 4
        #expect(set.check(.f12, for: .tabNotes) == .conflict("서랍 열기·닫기"))
        #expect(set.check(Shortcut(keyCode: 122, modifiers: 0), for: .openDrawer) == .conflict("메모/할 일 탭")) // F1
        #expect(set.check(q, for: .quit) == .needsCommand)
        #expect(set.check(q, for: .openDrawer) == .needsModifier)
        #expect(set.check(Shortcut(keyCode: 12, modifiers: M.command | M.option), for: .quit) == .ok)
        #expect(set.check(Shortcut(keyCode: 9999, modifiers: 0), for: .tabNotes) == .unsupported)
    }

    @Test func conflicts() {
        #expect(set.check(Shortcut(keyCode: 120, modifiers: 0), for: .tabNotes) == .conflict("즐겨찾기 탭")) // F2
        #expect(set.check(Shortcut(keyCode: 8, modifiers: M.command), for: .quit) == .conflict("복사"))
        #expect(set.check(Shortcut(keyCode: 48, modifiers: 0), for: .tabNotes) == .conflict("들여쓰기(메모)"))
        #expect(set.check(.f12, for: .tabSettings) == .conflict("서랍 열기·닫기"))
        #expect(set.check(.f12, for: .openDrawer) == .ok) // 자기 자신은 충돌 아님
    }

    @Test func changeAndStore() {
        var s = set
        s[.tabNotes] = Shortcut(keyCode: 83, modifiers: 0) // 키패드 1로 바꿔도 윗줄 1로 저장
        #expect(s[.tabNotes] == Shortcut(keyCode: 18, modifiers: 0))
        var c = set
        c[.tabFavorites] = Shortcut(keyCode: 19, modifiers: 0)
        #expect(c.check(Shortcut(keyCode: 84, modifiers: 0), for: .tabNotes) == .conflict("즐겨찾기 탭")) // 키패드 2
        s[.quit] = Shortcut(keyCode: 12, modifiers: M.command | M.shift)
        #expect(!s.isDefault(.quit) && !s.isAllDefault)
        let packed = ShortcutSet.pack(s[.quit])
        #expect(ShortcutSet.unpack(packed, fallback: .f12) == s[.quit])
        #expect(ShortcutSet.unpack(-5, fallback: .f12) == .f12)
        #expect(ShortcutSet.unpack(9999, fallback: .f12) == .f12)
    }
}

struct SideWindowTests {
    let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)

    @Test func opensRightOfDrawer() {
        let drawer = CGRect(x: 645, y: 500, width: 420, height: 575)
        #expect(Layout.sideWindowFrame(drawer: drawer, width: 300, gap: 8, screenFrame: screen)
                == CGRect(x: 1073, y: 500, width: 300, height: 575))
    }

    @Test func flipsLeftNearRightEdge() {
        let drawer = CGRect(x: 1300, y: 500, width: 400, height: 300)
        #expect(Layout.sideWindowFrame(drawer: drawer, width: 300, gap: 8, screenFrame: screen).minX == 992)
    }
}
