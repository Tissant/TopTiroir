import Testing

/// v0.2.1: 들여쓰기 너비, 서랍·창 색상(글자색 자동)
struct IndentTests {
    @Test func clampAndParse() {
        #expect(Indent.clampedWidth(0) == 1)
        #expect(Indent.clampedWidth(4) == 4)
        #expect(Indent.clampedWidth(20) == 8)
        #expect(Indent.parsedWidth(" 6 ") == 6)
        #expect(Indent.parsedWidth("99") == 8)
        #expect(Indent.parsedWidth("-3") == 1)
        #expect(Indent.parsedWidth("네") == nil)
        #expect(Indent.spaces(3) == "   ")
    }

    @Test func outdentRemovesUpToWidth() {
        #expect(Indent.outdent("        글", width: 4) == "    글")
        #expect(Indent.outdent("  글", width: 4) == "글")            // 공백이 너비보다 적으면 있는 만큼
        #expect(Indent.outdent("글", width: 4) == "글")
        #expect(Indent.outdent("    가\n  나\n다\n", width: 4) == "가\n나\n다\n")
        #expect(Indent.outdent("\t글", width: 4) == "\t글")           // 탭 문자는 건드리지 않음
    }
}

struct DrawerColorTests {
    @Test func darkTextOnLightBackground() {
        #expect(HexColor.prefersDarkText(on: RGB(red: 1, green: 1, blue: 1)))
        #expect(HexColor.prefersDarkText(on: HexColor.parse("#F5A623")!))   // 주황: 검은 글자
        #expect(!HexColor.prefersDarkText(on: RGB(red: 0, green: 0, blue: 0)))
        #expect(!HexColor.prefersDarkText(on: HexColor.parse("#2E3240")!))  // 어두운 남색: 흰 글자
    }

    @Test func lookPerMode() {
        #expect(DrawerLook.isDark(mode: .standard, appearance: .system, customHex: "#FFFFFF") == nil)
        #expect(DrawerLook.isDark(mode: .standard, appearance: .dark, customHex: "#FFFFFF") == true)
        #expect(DrawerLook.isDark(mode: .standard, appearance: .light, customHex: "#000000") == false)
        #expect(DrawerLook.isDark(mode: .custom, appearance: .dark, customHex: "#FFFFFF") == false)
        #expect(DrawerLook.isDark(mode: .custom, appearance: .light, customHex: "#101010") == true)
        #expect(DrawerLook.isDark(mode: .custom, appearance: .light, customHex: "엉뚱함") == nil)
    }
}

struct EditCommandTests {
    @Test(arguments: [(UInt16(0), EditCommand.selectAll), (8, .copy), (9, .paste), (7, .cut), (6, .undo)])
    func commandKeys(keyCode: UInt16, expected: EditCommand) {
        // 한글 입력 소스여도 키 코드는 같다(글자는 ㅁ·ㅊ·ㅍ·ㅌ·ㅋ로 들어옴) → 키 코드만 보므로 같은 결과
        #expect(EditCommand.from(keyCode: keyCode, command: true, shift: false, option: false, control: false) == expected)
    }

    @Test func shiftZIsRedoOthersIgnored() {
        #expect(EditCommand.from(keyCode: 6, command: true, shift: true, option: false, control: false) == .redo)
        #expect(EditCommand.from(keyCode: 8, command: true, shift: true, option: false, control: false) == nil)
        #expect(EditCommand.from(keyCode: 8, command: false, shift: false, option: false, control: false) == nil) // C만
        #expect(EditCommand.from(keyCode: 8, command: true, shift: false, option: true, control: false) == nil)   // ⌥⌘C
        #expect(EditCommand.from(keyCode: 0, command: true, shift: false, option: false, control: true) == nil)   // ⌃⌘A
        #expect(EditCommand.from(keyCode: 12, command: true, shift: false, option: false, control: false) == nil) // ⌘Q는 따로
        #expect(EditCommand.copy.selectorName == "copy:")
    }
}
