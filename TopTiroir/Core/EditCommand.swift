/// 편집 단축키 → 편집 명령. 글자가 아니라 키 위치(키 코드)로 본다.
/// 한글 입력 중에는 ⌘A가 「ㅁ」처럼 한글 자모로 들어와 글자로는 알아볼 수 없기 때문.
enum EditCommand: String, Sendable {
    case undo, redo, cut, copy, paste, selectAll

    /// ⌘만(⌃·⌥ 없이) 눌렸을 때만. ⇧는 Z(다시 실행)에만 허용.
    static func from(keyCode: UInt16, command: Bool, shift: Bool, option: Bool, control: Bool) -> EditCommand? {
        guard command, !option, !control else { return nil }
        switch (keyCode, shift) {
        case (6, false): return .undo        // Z
        case (6, true): return .redo         // ⇧Z
        case (7, false): return .cut         // X
        case (8, false): return .copy        // C
        case (9, false): return .paste       // V
        case (0, false): return .selectAll   // A
        default: return nil
        }
    }

    /// 입력칸에 보낼 동작 이름
    var selectorName: String { rawValue + ":" }
}
