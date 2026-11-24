import Testing

struct V080Tests {
    @Test func 열면_바로_닫기는_기본_꺼짐() {
        #expect(SettingsDefault.closeOnOpen == false)
        #expect(SettingsKey.closeOnOpen == "closeOnOpen")
    }
}

struct QuickMemoTests {
    @Test func 빠른메모는_전역키이고_수정키가_필요하다() {
        #expect(ShortcutAction.quickMemo.isGlobal && ShortcutAction.openDrawer.isGlobal && !ShortcutAction.quit.isGlobal)
        let set = ShortcutSet.defaults
        #expect(set[.quickMemo].displayName == "⌃⌥M")
        #expect(set.check(Shortcut(keyCode: 46, modifiers: 0), for: .quickMemo) == .needsModifier)
        #expect(set.check(Shortcut(keyCode: 122, modifiers: 0), for: .quickMemo) == .conflict(ShortcutAction.tabNotes.title))
        #expect(set.check(Shortcut(keyCode: 46, modifiers: Shortcut.Modifier.command), for: .quickMemo) == .ok)
    }
}
