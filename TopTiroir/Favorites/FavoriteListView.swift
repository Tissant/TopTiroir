import SwiftUI
import UniformTypeIdentifiers

/// 크기 모음(서랍 탭과 목록 창이 다름)
struct FavoriteMetrics {
    var rowHeight: CGFloat
    var fontSize: CGFloat
    var iconSize: CGFloat
    var scale: CGFloat
}

/// 끌어서 순서 바꾸기 전용 종류(파일·주소로 잘못 읽히지 않게, 다른 앱으로는 나가지 않음)
extension UTType {
    static let topTiroirFavorite = UTType(exportedAs: FavoriteDrop.reorderType)
}

/// 한 목록(맨 위 목록 또는 폴더 안): 맨 위 「+ 추가」(편집 시작) / 편집 중이면 [추가할 것 ▾][저장], 그 아래 줄들.
/// 편집하는 동안에는 바깥을 눌러도 서랍이 닫히지 않아 Finder에서 끌어다 놓을 수 있고, 줄을 끌어 순서를 바꾼다.
struct FavoriteListView: View {
    @Bindable var model: DrawerModel
    let path: [UUID]
    /// 0 = 서랍, 1~3 = 목록 창
    let level: Int
    let m: FavoriteMetrics
    let palette: DrawerPalette
    /// 목록 창: 맨 위 단추·입력 줄은 고정하고 항목만 스크롤(서랍 탭은 탭 전체가 스크롤되므로 false)
    var scrollItems = false
    /// 서랍 탭: 목록 아래 빈 곳까지 놓을 자리로 쓰려고 채울 높이
    var minHeight: CGFloat = 0

    private var store: FavoritesStore { model.favorites }
    private var editing: Bool { model.favoritesEditing }
    @State private var fixedHeight: CGFloat = 0
    @State private var itemsHeight: CGFloat = 0

    enum Input: Equatable { case none, web, group }
    @State private var input: Input = .none
    @State private var nameText = ""
    @State private var addressText = ""
    @State private var inputError: String?
    @State private var renaming: UUID?
    @State private var renameText = ""
    @State private var confirmDelete: UUID?
    @State private var hovering: UUID?
    @State private var dropTarget = false
    @State private var reorderTarget: UUID?
    @State private var reorderZone: FavoriteDrop.Zone = .before

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                if editing { addActions }
                switch input {
                case .none: EmptyView()
                case .web: webInput
                case .group: groupInput
                }
                Rectangle().fill(palette.divider).frame(height: 1).padding(.vertical, 2)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fixedHeight = $0; report() }
            if scrollItems {
                ScrollView { itemsStack }
                    .scrollIndicators(.automatic)
            } else {
                itemsStack
            }
            // 목록 아래 빈 곳: 여기에 놓으면 맨 끝으로(놓을 때 맨 아래 삽입선)
            VStack(spacing: 0) {
                Rectangle().fill(Brand.orange.opacity(dropTarget ? 1 : 0)).frame(height: 2)
                Color.clear
            }
            .frame(minHeight: 10)
            .frame(maxHeight: scrollItems ? 10 : .infinity)
        }
        .frame(minHeight: minHeight, alignment: .top)
        .contentShape(Rectangle())
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 6).stroke(Brand.orange.opacity(dropTarget ? 0.8 : 0), lineWidth: 1.5))
        .onDrop(of: [.topTiroirFavorite, .fileURL, .url], isTargeted: $dropTarget) { providers in
            accept(providers, into: path, before: nil)
        }
        .onChange(of: model.openCount) { reset() }
        .onChange(of: editing) { _, now in if !now { reset() } }
    }

    /// 목록 창 높이 계산용: 고정 줄 + 항목들(입력·확인 줄 포함)
    private func report() {
        guard level > 0 else { return }
        // + 아래 빈 곳(놓을 자리 10) + 바깥 여백 4
        model.reportColumnHeight(level, fixed: fixedHeight + 4 + 14, items: itemsHeight)
    }

    private var itemsStack: some View {
        let items = store.document.list(at: path) ?? []
        return VStack(alignment: .leading, spacing: 0) {
            if items.isEmpty {
                Text(level == 0 ? (editing ? String(localized: "Finder에서 앱·파일·폴더를 끌어다 놓거나\n위 단추로 넣어 보세요")
                                           : String(localized: "「수정」을 누르고 앱·파일·폴더·웹 주소를\n끌어다 놓거나 골라서 넣어 보세요"))
                                : String(localized: "비어 있어요"))
                    .font(.system(size: m.fontSize * 0.95))
                    .foregroundStyle(palette.tabText.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: level == 0 ? m.rowHeight * 3 : m.rowHeight)
            }
            ForEach(items) { item in
                if item.kind == .separator {
                    separatorRow(item, next: items.nextID(after: item.id))
                } else if confirmDelete == item.id {
                    deleteConfirm(item)
                } else if renaming == item.id {
                    renameRow(item)
                } else {
                    row(item, next: items.nextID(after: item.id))
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { itemsHeight = $0; report() }
    }

    // MARK: 맨 위: 추가 / 편집 중

    /// 수정 모드가 아니면 「추가」(누르면 수정 모드), 수정 중이면 「수정 중」 표시와 「저장」
    @ViewBuilder private var topBar: some View {
        HStack(spacing: 6 * m.scale) {
            if editing {
                Label("수정 중", systemImage: "pencil")
                    .font(.system(size: m.fontSize * 0.92, weight: .medium))
                    .foregroundStyle(Brand.orange)
                    .help("수정하는 동안은 바깥을 눌러도 서랍이 닫히지 않아요. 「저장」을 누르면 끝나요.")
                Spacer(minLength: 4)
                // 창이 앞에 있지 않아도 늘 주황으로 보이게 직접 그린 단추
                Button { model.favoritesEditing = false } label: {
                    Text("저장")
                        .font(.system(size: m.fontSize * 0.92, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10 * m.scale)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Brand.orange))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("수정을 마쳐요. 다시 바깥을 누르면 서랍이 닫혀요.")
            } else {
                Spacer(minLength: 0)
                Button { model.favoritesEditing = true } label: {
                    Text("수정")
                        .font(.system(size: m.fontSize * 0.92, weight: .semibold))
                        .foregroundStyle(Brand.orange)
                        .padding(.horizontal, 8 * m.scale)
                        .padding(.vertical, 2)
                        .background(Capsule().stroke(Brand.orange.opacity(0.8), lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("수정 모드: 앱·파일·Finder 폴더·웹 주소를 넣고, 끌어서 순서를 바꿔요. 바깥을 눌러도 서랍이 닫히지 않아요.")
            }
        }
        .padding(.horizontal, 6 * m.scale)
        .frame(height: m.rowHeight)
    }

    /// 수정 중 추가 단추(아이콘만, 이름은 툴팁): Finder에서 고르기 · 웹 주소 · 새 폴더 · 목록 구분선
    private var addActions: some View {
        HStack(spacing: 4 * m.scale) {
            addButton("plus.rectangle.on.folder", help: String(localized: "Finder에서 고르기")) {
                store.noticeLevel = level
                model.onChooseFiles?(path)
            }
            addButton("globe", help: String(localized: "웹 주소 추가")) { startInput(.web) }
            addButton("folder.badge.plus", help: String(localized: "새 폴더 만들기")) {
                store.noticeLevel = level
                if FavoritesDocument.canAddGroup(at: path) { startInput(.group) }
                else { store.say(FavoritesStore.tooDeepMessage) }
            }
            addButton("minus", help: String(localized: "목록 구분선 추가")) { store.addSeparator(at: path) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4 * m.scale)
        .padding(.bottom, 2)
    }

    /// 아이콘만 있는 단추(이름은 툴팁)
    private func addButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: m.fontSize * 0.92))
                .frame(width: m.rowHeight * 1.05, height: m.rowHeight * 0.82)
                .background(RoundedRectangle(cornerRadius: 5).fill(palette.tabFill))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    // MARK: 줄

    private func row(_ item: FavoriteItem, next: UUID?) -> some View {
        let selected = item.kind == .group && model.columnStack.count > level && model.columnStack[level] == item.id
        let missing = store.isMissing(item)
        let base = HStack(spacing: 6 * m.scale) {
            if let icon = store.appIcon(item, size: m.iconSize) {
                Image(nsImage: icon).resizable().interpolation(.high).frame(width: m.iconSize, height: m.iconSize)
            } else {
                FavoriteIcon(kind: item.kind, size: m.iconSize, dark: palette.dark)
            }
            if editing { dragHandle(item) }   // 이 손잡이를 끌어야만 줄이 움직인다
            Text(item.name)
                .font(.system(size: m.fontSize))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if item.kind == .group {
                Image(systemName: "chevron.right")
                    .font(.system(size: m.fontSize * 0.8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(missing ? 0.4 : 1)
        .padding(.horizontal, 6 * m.scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: m.rowHeight)
        .background {
            RoundedRectangle(cornerRadius: 5 * m.scale, style: .continuous)
                .fill(selected ? (palette.dark ? Color.white.opacity(0.16) : Color.white.opacity(0.85))
                      : hovering == item.id ? palette.tabFill : .clear)
                .shadow(color: selected && !palette.dark ? .black.opacity(0.08) : .clear, radius: 1, y: 0.5)
        }
        .overlay { dropMark(item) }
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside ? item.id : (hovering == item.id ? nil : hovering)
            model.hoveredFavoriteKind = inside ? FavoriteKindName.of(item.kind) : nil
        }
        .contextMenu { menuItems(item) }
        .help(missing ? String(localized: "찾을 수 없어요: \(item.location ?? item.name)") : (item.location ?? item.name))
        .onDrop(of: [.topTiroirFavorite, .fileURL, .url], delegate: rowDelegate(item, next: next))
        // 수정 중이 아니면 단추로(첫 클릭에 바로 반응), 수정 중이면 손잡이 끌기를 막지 않게 탭 동작으로
        return Group {
            if editing {
                base.onTapGesture { model.tapFavorite(item, level: level) }
            } else {
                Button { model.tapFavorite(item, level: level) } label: { base }
                    .buttonStyle(.plain)
            }
        }
    }

    /// 놓을 자리 표시: 위·아래 주황 선, 폴더 안이면 줄 전체 테두리
    @ViewBuilder private func dropMark(_ item: FavoriteItem) -> some View {
        if reorderTarget == item.id {
            switch reorderZone {
            case .before: VStack { Rectangle().fill(Brand.orange).frame(height: 2); Spacer(minLength: 0) }
            case .after: VStack { Spacer(minLength: 0); Rectangle().fill(Brand.orange).frame(height: 2) }
            case .into: RoundedRectangle(cornerRadius: 5).stroke(Brand.orange, lineWidth: 1.5)
            }
        }
    }

    private func rowDelegate(_ item: FavoriteItem, next: UUID?) -> RowDropDelegate {
        RowDropDelegate(item: item, height: item.kind == .separator ? 12 : m.rowHeight,
                        target: $reorderTarget, zone: $reorderZone) { providers, zone in
            switch zone {
            case .into: return accept(providers, into: path + [item.id], before: nil)
            case .before: return accept(providers, into: path, before: item.id)
            case .after: return accept(providers, into: path, before: next)
            }
        }
    }

    /// 순서 손잡이(수정 중에만). 이 손잡이를 끌어야 줄이 움직인다.
    private func dragHandle(_ item: FavoriteItem) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: m.fontSize * 0.8))
            .foregroundStyle(.secondary)
            .frame(width: m.iconSize, height: m.rowHeight * 0.8)
            .contentShape(Rectangle())
            .help("끌어서 순서 바꾸기·다른 폴더로 옮기기")
            .onDrag {
                let p = NSItemProvider()
                let data = Data(item.id.uuidString.utf8)
                p.registerDataRepresentation(forTypeIdentifier: UTType.topTiroirFavorite.identifier,
                                             visibility: .ownProcess) { done in done(data, nil); return nil }
                return p
            }
    }

    /// 목록 구분선 줄: 가는 선, 수정 중에는 손잡이로 옮기고 오른쪽 클릭으로 삭제
    private func separatorRow(_ item: FavoriteItem, next: UUID?) -> some View {
        HStack(spacing: 6 * m.scale) {
            if editing {
                dragHandle(item)
                Text("구분선").font(.system(size: m.fontSize * 0.75)).foregroundStyle(.tertiary)
            }
            Rectangle().fill(palette.divider).frame(height: 1)
        }
        .padding(.horizontal, 6 * m.scale)
        .frame(height: editing ? m.rowHeight * 0.7 : 9)
        .overlay { dropMark(item) }
        .contentShape(Rectangle())
        .contextMenu { Button(FavoriteMenu.removeSeparator) { store.remove(item.id, at: path) } }   // 확인 없이 바로(백업은 남김)
        .onDrop(of: [.topTiroirFavorite, .fileURL, .url], delegate: rowDelegate(item, next: next))
    }

    @ViewBuilder private func menuItems(_ item: FavoriteItem) -> some View {
        Button(FavoriteMenu.rename) { renaming = item.id; renameText = item.name }
        Button(FavoriteMenu.remove) {
            if item.kind == .group && item.descendantCount > 0 { confirmDelete = item.id }
            else { remove(item) }
        }
    }

    private func remove(_ item: FavoriteItem) {
        // 지운 폴더가 열려 있었으면 그 칸부터 닫는다.
        if let i = model.columnStack.firstIndex(of: item.id) { model.columnStack = Array(model.columnStack.prefix(i)) }
        store.remove(item.id, at: path)
        confirmDelete = nil
    }

    private func deleteConfirm(_ item: FavoriteItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("「\(item.name)」 폴더와 안의 \(item.descendantCount)개를 즐겨찾기에서 지울까요? 되돌릴 수 없어요. (실제 파일은 그대로)")
                .font(.system(size: m.fontSize * 0.92, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("취소") { confirmDelete = nil }
                Button("지우기", role: .destructive) { remove(item) }
            }
            .controlSize(.small)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.10)))
    }

    private func renameRow(_ item: FavoriteItem) -> some View {
        HStack(spacing: 6 * m.scale) {
            FavoriteIcon(kind: item.kind, size: m.iconSize, dark: palette.dark)
            TextField("이름", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: m.fontSize))
                .onSubmit { store.rename(item.id, to: renameText, at: path); renaming = nil }
            Button("취소") { renaming = nil }.controlSize(.small)
        }
        .padding(.horizontal, 6 * m.scale)
        .frame(minHeight: m.rowHeight)
    }

    // MARK: 입력 줄

    private var webInput: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("이름 (비워 두면 사이트 이름)", text: $nameText).textFieldStyle(.roundedBorder)
            TextField("https://", text: $addressText).textFieldStyle(.roundedBorder)
                .onSubmit(addWeb)
            inputFooter(ok: String(localized: "넣기"), action: addWeb)
        }
        .font(.system(size: m.fontSize))
        .padding(4)
    }

    private var groupInput: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("폴더 이름", text: $nameText).textFieldStyle(.roundedBorder)
                .onSubmit(addGroup)
            inputFooter(ok: String(localized: "만들기"), action: addGroup)
        }
        .font(.system(size: m.fontSize))
        .padding(4)
    }

    private func inputFooter(ok: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let inputError {
                Text(inputError).font(.system(size: m.fontSize * 0.9)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("취소") { input = .none; inputError = nil }
                Button(ok, action: action).buttonStyle(.borderedProminent).tint(Brand.orange)
            }
            .controlSize(.small)
        }
    }

    private func startInput(_ kind: Input) {
        nameText = ""; addressText = ""; inputError = nil
        input = kind
    }

    private func addWeb() {
        if let error = store.addWeb(name: nameText, address: addressText, at: path) { inputError = error } else { input = .none }
    }

    private func addGroup() {
        if let error = store.addGroup(name: nameText, at: path) { inputError = error } else { input = .none }
    }

    private func reset() {
        input = .none; inputError = nil; renaming = nil; confirmDelete = nil; reorderTarget = nil
    }

    // MARK: 끌어다 놓기

    /// 순서 바꾸기(같은 목록의 줄) 또는 Finder·브라우저에서 온 위치 추가
    private func accept(_ providers: [NSItemProvider], into target: [UUID], before: UUID?) -> Bool {
        reorderTarget = nil
        // 줄을 끌어 놓음: 같은 목록이면 순서, 다른 목록·폴더면 옮기기(3단계 검사). 파일·주소로 읽지 않는다.
        store.noticeLevel = level   // 안내는 이 드롭을 받은 창에만
        let types = providers.flatMap(\.registeredTypeIdentifiers)
        if FavoriteDrop.classify(typeIdentifiers: types) == .reorder,
           let own = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.topTiroirFavorite.identifier) }) {
            _ = own.loadDataRepresentation(forTypeIdentifier: UTType.topTiroirFavorite.identifier) { data, _ in
                guard let data, let id = UUID(uuidString: String(decoding: data, as: UTF8.self)) else { return }
                Task { @MainActor in model.favorites.relocate(id, to: target, before: before) }
            }
            return true
        }
        let fileProviders = providers.filter { $0.canLoadObject(ofClass: URL.self) }
        guard !fileProviders.isEmpty else { return false }
        let collector = URLCollector(count: fileProviders.count) { urls in
            Task { @MainActor in model.favorites.add(urls: urls, at: target) }
        }
        for p in fileProviders {
            _ = p.loadObject(ofClass: URL.self) { url, _ in collector.put(url) }
        }
        return true
    }
}

/// 줄 위에 끌어 놓기: 줄의 위·아래·가운데(폴더)를 보고 자리를 정한다.
struct RowDropDelegate: DropDelegate {
    let item: FavoriteItem
    let height: CGFloat
    @Binding var target: UUID?
    @Binding var zone: FavoriteDrop.Zone
    let perform: ([NSItemProvider], FavoriteDrop.Zone) -> Bool

    private func zoneAt(_ info: DropInfo) -> FavoriteDrop.Zone {
        FavoriteDrop.zone(y: info.location.y, height: height, isFolder: item.kind == .group)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        target = item.id
        zone = zoneAt(info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if target == item.id { target = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        let z = zoneAt(info)
        target = nil
        return perform(info.itemProviders(for: [.topTiroirFavorite, .fileURL, .url]), z)
    }
}

extension Array where Element == FavoriteItem {
    /// 바로 다음 줄 id(마지막이면 nil = 맨 끝)
    func nextID(after id: UUID) -> UUID? {
        guard let i = firstIndex(where: { $0.id == id }), i + 1 < count else { return nil }
        return self[i + 1].id
    }
}

/// 끌어다 놓은 여러 위치를 다 받은 뒤 한 번에 넘긴다(받는 순서는 섞일 수 있음).
private final class URLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []
    private var left: Int
    private let done: @Sendable ([URL]) -> Void

    init(count: Int, done: @escaping @Sendable ([URL]) -> Void) {
        left = count
        self.done = done
    }

    func put(_ url: URL?) {
        lock.lock()
        if let url { urls.append(url) }
        left -= 1
        let finished = left == 0
        let result = urls
        lock.unlock()
        if finished { done(result) }
    }
}

/// 서랍의 즐겨찾기 탭
struct FavoritesTabView: View {
    @Bindable var model: DrawerModel
    let scale: CGFloat
    let text: CGFloat
    let palette: DrawerPalette
    /// 서랍 내용 높이(목록 아래 빈 곳도 놓을 자리로)
    var minHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4 * scale) {
            if let notice = model.favorites.notice, model.favorites.noticeLevel == 0 {
                NoticeBanner(text: notice, size: 11 * text) { model.favorites.notice = nil }
            }
            FavoriteListView(model: model, path: [], level: 0,
                             m: FavoriteMetrics(rowHeight: 24 * text, fontSize: 12 * text, iconSize: 14 * text, scale: scale),
                             palette: palette, minHeight: max(minHeight - 12 * scale, 0))
        }
        .padding(.top, 6 * scale)
    }
}

/// 서랍 안에 그리는 안내(시스템 알림창은 초점 없는 서랍에서 안 보일 수 있음). 「확인」 또는 4초 뒤 사라짐.
struct NoticeBanner: View {
    let text: String
    let size: CGFloat
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle.fill").foregroundStyle(Brand.orange)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("확인", action: dismiss).controlSize(.mini)
        }
        .font(.system(size: size))
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Brand.orange.opacity(0.6), lineWidth: 1))
        .padding(.bottom, 2)
    }
}

/// 오른쪽 목록 창 내용: 「폴더 이름 · N개」 + 목록(넘치면 스크롤)
struct FavoriteColumnView: View {
    @Bindable var model: DrawerModel
    /// 1~3
    let level: Int
    @Environment(\.colorScheme) private var scheme
    @AppStorage(SettingsKey.drawerScale) private var storedScale = SettingsDefault.drawerScale
    @AppStorage(SettingsKey.textScale) private var storedText = SettingsDefault.textScale
    @AppStorage(SettingsKey.drawerOpacity) private var storedWindowOpacity = SettingsDefault.drawerOpacity
    @AppStorage(SettingsKey.textOpacity) private var storedTextOpacity = SettingsDefault.textOpacity
    @AppStorage(SettingsKey.drawerColorMode) private var colorMode = SettingsDefault.drawerColorMode
    @AppStorage(SettingsKey.drawerColor) private var customColorHex = SettingsDefault.drawerColor

    var body: some View {
        let palette = DrawerPalette(dark: scheme == .dark)
        let s = CGFloat(Layout.clampedScale(storedScale)), t = CGFloat(Layout.clampedScale(storedText))
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let stack = model.columnStack
        let path = Array(stack.prefix(level))
        let group = stack.count >= level ? model.favorites.document.find(stack[level - 1]) : nil
        VStack(alignment: .leading, spacing: 2) {
            if let group {
                Text("\(group.name) · \(group.visibleChildCount)개")
                    .font(.system(size: 11 * t, weight: .bold))
                    .foregroundStyle(palette.sectionTitle)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .frame(height: Layout.listWindowHeader, alignment: .leading)
                if let notice = model.favorites.notice, model.favorites.noticeLevel == level {
                    NoticeBanner(text: notice, size: 11 * t) { model.favorites.notice = nil }
                }
                // 맨 위 단추·입력 줄은 고정, 항목만 스크롤. 입력 줄이 열리면 창도 그만큼 길어진다(최대 450).
                FavoriteListView(model: model, path: path, level: level,
                                 m: FavoriteMetrics(rowHeight: 24 * t, fontSize: 12 * t, iconSize: 12 * t, scale: s),
                                 palette: palette, scrollItems: true)
            }
        }
        .opacity(Layout.clampedOpacity(model.textOpacityPreview ?? storedTextOpacity, range: Layout.textOpacityRange))
        .padding(Layout.listWindowPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            ZStack {
                VisualEffectBlur()
                if colorMode == DrawerColorMode.custom.rawValue {
                    Color(nsColor: NSColor(ttHex: customColorHex))
                } else {
                    LinearGradient(colors: [palette.glassTop, palette.glassBottom], startPoint: .top, endPoint: .bottom)
                }
            }
            .opacity(Layout.clampedOpacity(model.windowOpacityPreview ?? storedWindowOpacity, range: Layout.windowOpacityRange))
        }
        .clipShape(shape)
        .overlay(shape.stroke(palette.border.opacity(0.6), lineWidth: 1))
    }
}
