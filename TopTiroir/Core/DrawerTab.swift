/// 서랍의 책갈피 탭
enum DrawerTab: String, CaseIterable, Identifiable, Sendable {
    case notes, favorites, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .notes: "메모/할 일"
        case .favorites: "즐겨찾기"
        case .settings: "설정"
        }
    }
}

/// 서랍을 열 때 보여 줄 탭
enum OpenTabMode: String, CaseIterable, Sendable {
    case last, notes, favorites

    var title: String {
        switch self {
        case .last: "마지막에 본 탭"
        case .notes: "메모/할 일"
        case .favorites: "즐겨찾기"
        }
    }

    /// 열 때 고를 탭. 마지막 탭 기록이 없거나 잘못됐으면 메모/할 일.
    func tab(lastTab: String?) -> DrawerTab {
        switch self {
        case .last: lastTab.flatMap(DrawerTab.init(rawValue:)) ?? .notes
        case .notes: .notes
        case .favorites: .favorites
        }
    }
}
