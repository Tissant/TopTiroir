import CoreGraphics
import Testing

/// v0.2.2: 단축키 묶음(기본값·검사·충돌·탭 이동·저장)
struct ShortcutSetTests {
    typealias M = Shortcut.Modifier
    let set = ShortcutSet.defaults

    @Test func defaults() {
        #expect(set[.openDrawer] == .f12)
        #expect(set[.tabNotes].displayName == "1")
        #expect(set[.tabFavorites].displayName == "2")
        #expect(set[.tabSettings].displayName == "3")
        #expect(set[.quit].displayName == "⌘Q")
        #expect(set.isAllDefault)
    }

    @Test func tabKeysOnlyWithoutCursor() {
        #expect(set.localAction(keyCode: 18, modifiers: 0, textFocused: false) == .showTab(.notes))
        #expect(set.localAction(keyCode: 19, modifiers: 0, textFocused: false) == .showTab(.favorites))
        #expect(set.localAction(keyCode: 20, modifiers: 0, textFocused: false) == .showTab(.settings))
        #expect(set.localAction(keyCode: 18, modifiers: 0, textFocused: true) == nil)   // 입력칸이면 글자로
        #expect(set.localAction(keyCode: 18, modifiers: M.command, textFocused: false) == nil) // ⌘1은 다른 키
    }

    @Test func keypadDigitsWorkToo() {
        #expect(set.localAction(keyCode: 83, modifiers: 0, textFocused: false) == .showTab(.notes))   // 키패드 1
        #expect(set.localAction(keyCode: 85, modifiers: 0, textFocused: false) == .showTab(.settings)) // 키패드 3
    }

    @Test func quitWorksEvenWithCursor() {
        #expect(set.localAction(keyCode: 12, modifiers: M.command, textFocused: true) == .quit)
        #expect(set.localAction(keyCode: 12, modifiers: 0, textFocused: false) == nil) // Q만
    }

    @Test func checks() {
        let q = Shortcut(keyCode: 12, modifiers: 0)
        #expect(set.check(Shortcut(keyCode: 53, modifiers: 0), for: .tabNotes) == .cancel)
        #expect(set.check(Shortcut(keyCode: 21, modifiers: 0), for: .tabNotes) == .ok)              // 4
        #expect(set.check(q, for: .quit) == .needsCommand)
        #expect(set.check(q, for: .openDrawer) == .needsModifier)
        #expect(set.check(Shortcut(keyCode: 12, modifiers: M.command | M.option), for: .quit) == .ok)
        #expect(set.check(Shortcut(keyCode: 9999, modifiers: 0), for: .tabNotes) == .unsupported)
    }

    @Test func conflicts() {
        #expect(set.check(Shortcut(keyCode: 19, modifiers: 0), for: .tabNotes) == .conflict("즐겨찾기 탭"))
        #expect(set.check(Shortcut(keyCode: 84, modifiers: 0), for: .tabNotes) == .conflict("즐겨찾기 탭")) // 키패드 2
        #expect(set.check(Shortcut(keyCode: 8, modifiers: M.command), for: .quit) == .conflict("복사"))
        #expect(set.check(Shortcut(keyCode: 48, modifiers: 0), for: .tabNotes) == .conflict("들여쓰기(메모)"))
        #expect(set.check(.f12, for: .tabSettings) == .conflict("서랍 열기·닫기"))
        #expect(set.check(.f12, for: .openDrawer) == .ok) // 자기 자신은 충돌 아님
    }

    @Test func changeAndStore() {
        var s = set
        s[.tabNotes] = Shortcut(keyCode: 83, modifiers: 0) // 키패드 1로 바꿔도 윗줄 1로 저장
        #expect(s[.tabNotes] == Shortcut(keyCode: 18, modifiers: 0))
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
