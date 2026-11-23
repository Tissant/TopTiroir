/// 메모 칸 들여쓰기(Tab = 공백 N칸)
enum Indent {
    static let widthRange: ClosedRange<Int> = 1...8
    static let defaultWidth = 4

    static func clampedWidth(_ value: Int) -> Int {
        min(max(value, widthRange.lowerBound), widthRange.upperBound)
    }

    /// 칸 입력칸에 친 글자 → 칸 수. 숫자가 아니면 nil(이전 값 유지), 범위를 벗어나면 가까운 값.
    static func parsedWidth(_ text: String) -> Int? {
        guard let n = Int(text.trimmingCharacters(in: .whitespaces)) else { return nil }
        return clampedWidth(n)
    }

    static func spaces(_ width: Int) -> String {
        String(repeating: " ", count: clampedWidth(width))
    }

    /// 한 줄 앞에서 지울 공백 수: 줄 앞 공백과 너비 중 작은 값
    static func removableLeadingSpaces(_ line: Substring, width: Int) -> Int {
        min(line.prefix { $0 == " " }.count, clampedWidth(width))
    }

    /// Shift+Tab: 여러 줄(줄바꿈 포함 글)의 각 줄 앞 공백을 너비만큼 줄인다.
    static func outdent(_ text: String, width: Int) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in String(line.dropFirst(removableLeadingSpaces(line, width: width))) }
            .joined(separator: "\n")
    }
}
