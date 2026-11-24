import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 메모/할 일 탭: 위 메모, 아래 할 일(기본 3:2, 사이 손잡이로 조절). 둘은 따로 스크롤된다.
struct NotesTabView: View {
    @Bindable var model: DrawerModel
    private var store: NotesStore { model.notes }
    let height: CGFloat
    let scale: CGFloat
    /// 글자 크기 비율
    let text: CGFloat
    let palette: DrawerPalette

    @AppStorage(SettingsKey.indentWidth) private var indentWidth = SettingsDefault.indentWidth
    @State private var newTodo = ""
    @State private var confirmClearTodos = false
    @State private var showClearMenu = false
    @FocusState private var focus: Field?
    private enum Field { case newTodo }

    // 할 일 끌어서 순서 바꾸기
    @State private var draggingTodo: UUID?
    @State private var dropSlot: Int?
    @State private var todoScroll = ScrollPosition()
    @State private var scrollY: CGFloat = 0
    @State private var scrollMax: CGFloat = 0
    @State private var viewportH: CGFloat = 0
    /// 마지막으로 알려 준 포인터의 보이는 칸 안 세로 위치
    @State private var pointerVY: CGFloat = 0
    @State private var autoScrollTask: Task<Void, Never>?

    private var spacing: CGFloat { 8 * scale }
    private var rowHeight: CGFloat { 22 * text }

    /// 할 일 쪽 최소: 입력줄 + 구분선 + 할 일 두 줄(입력줄·스플릿 단추가 늘 보이게)
    private var todoMin: CGFloat { rowHeight * 3 + 6 * scale }
    private var memoMin: CGFloat { 40 * text }

    var body: some View {
        let split = Layout.memoTodoSplit(total: height, spacing: spacing, memoRatio: model.memoRatio,
                                         memoMin: memoMin, todoMin: todoMin)
        VStack(spacing: 0) {
            memoBox.frame(height: split.memo)
            splitHandle(available: max(height - spacing, 1))
            todoBox.frame(height: split.todo)
        }
        .padding(.top, 6 * scale)
        .frame(height: height + 6 * scale, alignment: .top)
        .onChange(of: model.openCount) {
            finishTodoDrag(move: false)
            // 새로 열면 펼친 ▾ 목록과 비우기 확인 줄은 접힌 상태로
            showClearMenu = false
            confirmClearTodos = false
        }
    }

    // MARK: 메모·할 일 사이 손잡이

    @State private var splitDragStart: (ratio: Double, mouseY: CGFloat)?

    /// 위아래로 끌어 메모·할 일 크기를 나눈다. 더블클릭하면 기본 3:2.
    private func splitHandle(available: CGFloat) -> some View {
        Capsule()
            .fill(splitDragStart != nil ? Brand.orange.opacity(0.8) : palette.handle)
            .frame(width: 28 * scale, height: 3 * scale)
            .frame(maxWidth: .infinity)
            .frame(height: spacing)
            .contentShape(Rectangle())
            .pointerStyle(.frameResize(position: .bottom))
            .help("끌어서 메모·할 일 크기 나누기 (더블클릭: 3:2)")
            .onTapGesture(count: 2) {
                model.memoRatio = Layout.memoRatioDefault
                UserDefaults.standard.set(model.memoRatio, forKey: SettingsKey.memoRatio)
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { _ in
                        let y = NSEvent.mouseLocation.y
                        if splitDragStart == nil { splitDragStart = (model.memoRatio, y) }
                        guard let start = splitDragStart else { return }
                        model.memoRatio = Layout.memoRatioAfterDrag(startRatio: start.ratio, startMouseY: start.mouseY,
                                                                    currentMouseY: y, available: available)
                    }
                    .onEnded { _ in
                        splitDragStart = nil
                        UserDefaults.standard.set(model.memoRatio, forKey: SettingsKey.memoRatio)
                    }
            )
    }

    // MARK: 메모

    private var memoBox: some View {
        let shape = RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
        return ZStack(alignment: .topLeading) {
            shape.fill(memoFill.shadow(.inner(color: .black.opacity(palette.dark ? 0.45 : 0.18), radius: 2.5 * scale, y: 1)))
            MemoTextView(text: Binding(get: { store.document.memo }, set: { store.setMemo($0) }),
                         fontSize: 12 * text, indentWidth: Indent.clampedWidth(indentWidth))
                .padding(.horizontal, 5 * scale)
                .padding(.vertical, 6 * scale)
            if store.document.memo.isEmpty {
                Text("메모를 적어 보세요")
                    .font(.system(size: 12 * text))
                    .foregroundStyle(palette.tabText.opacity(0.6))
                    .padding(.horizontal, 10 * scale)
                    .padding(.vertical, 6 * scale)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let notice = store.notice {
                Text(notice)
                    .font(.system(size: 10 * text))
                    .foregroundStyle(.secondary)
                    .padding(6 * scale)
            }
        }
    }

    /// 주변보다 어두운 칸
    private var memoFill: Color {
        palette.dark ? Color.black.opacity(0.30) : Color.black.opacity(0.06)
    }

    // MARK: 할 일

    private var todoBox: some View {
        VStack(spacing: 2 * scale) {
            HStack(spacing: 6 * scale) {
                HStack(spacing: 6 * scale) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Brand.orange)
                        .font(.system(size: 12 * text))
                    TextField("새 할 일 (↩ 추가)", text: $newTodo)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12 * text))
                        .focused($focus, equals: .newTodo)
                        .onSubmit(add)
                }
                .padding(.horizontal, 6 * scale)
                .frame(height: rowHeight)
                // 입력줄만 주변보다 밝게 해서 눈에 띄게 한다.
                .background(RoundedRectangle(cornerRadius: 6 * scale, style: .continuous).fill(inputFill))
                .overlay(RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                    .stroke(focus == .newTodo ? Brand.orange.opacity(0.7) : palette.divider, lineWidth: 1))
                // 스플릿 단추: 본체 = 완료된 일 삭제, ▾ = 할 일 비우기(서랍 안에 직접 그린 목록)
                splitButton
            }
            .zIndex(1)   // 펼친 목록이 아래 할 일 목록 위에 보이게
            .padding(.bottom, 2 * scale)
            if confirmClearTodos { clearTodosConfirm }
            Rectangle().fill(palette.divider).frame(height: 1)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(store.document.todos.enumerated()), id: \.element.id) { index, item in
                        TodoRow(item: item, height: rowHeight, scale: scale, text: text, palette: palette,
                                editDraft: editBinding(for: item),
                                onToggle: { store.toggleTodo(item.id) },
                                onDelete: { store.removeTodo(item.id) },
                                onBeginEdit: { model.beginTodoEdit(item) },
                                onCommitEdit: { model.commitTodoEdit() },
                                onDragStart: { beginTodoDrag(item.id) },
                                dragging: draggingTodo == item.id)
                            .overlay(alignment: .top) { slotLine(index) }
                            .onDrop(of: [.topTiroirTodo], delegate: dropDelegate(index: index))
                    }
                    if draggingTodo != nil {
                        // 맨 아래로 옮길 수 있게 끝에 빈 칸
                        Color.clear.frame(height: rowHeight)
                            .overlay(alignment: .top) { slotLine(store.document.todos.count) }
                            .onDrop(of: [.topTiroirTodo], delegate: dropDelegate(index: store.document.todos.count))
                    }
                }
            }
            .scrollPosition($todoScroll)
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in scrollY = y }
            .onScrollGeometryChange(for: CGFloat.self) { max($0.contentSize.height - $0.containerSize.height, 0) } action: { _, v in scrollMax = v }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportH = $0 }
            .scrollBounceBehavior(.basedOnSize)
            .overlay {
                if store.document.todos.isEmpty {
                    Text("할 일이 없어요")
                        .font(.system(size: 11 * text))
                        .foregroundStyle(palette.tabText.opacity(0.6))
                }
            }
        }
    }

    // MARK: 할 일 끌기

    /// 놓을 자리 표시(줄 위쪽 주황 선)
    @ViewBuilder private func slotLine(_ index: Int) -> some View {
        if dropSlot == index, draggingTodo != nil {
            Rectangle().fill(Brand.orange).frame(height: 2)
        }
    }

    private func dropDelegate(index: Int) -> TodoDropDelegate {
        TodoDropDelegate(
            update: { yInRow in
                pointerVY = CGFloat(index) * rowHeight + yInRow - scrollY
                updateSlot()
            },
            perform: {
                finishTodoDrag(move: true)
            })
    }

    private func updateSlot() {
        dropSlot = TodoDrag.slot(contentY: pointerVY + scrollY, rowHeight: rowHeight,
                                 count: store.document.todos.count)
    }

    private func beginTodoDrag(_ id: UUID) {
        draggingTodo = id
        dropSlot = nil
        autoScrollTask?.cancel()
        // 끄는 동안 가장자리에 닿으면 목록을 스크롤한다. 마우스를 놓으면(놓을 곳이 없어도) 끝낸다.
        autoScrollTask = Task { @MainActor in
            let step: Duration = .milliseconds(16)
            var sawPressed = false   // 끄는 동안 버튼 상태가 보고되지 않는 경우엔 끝냄 판단을 하지 않는다
            while !Task.isCancelled {
                let pressed = NSEvent.pressedMouseButtons & 1 != 0
                if pressed { sawPressed = true }
                else if sawPressed {
                    // 놓은 곳에서 받는 처리(performDrop)가 먼저 끝나도록 잠깐 기다렸다가 정리
                    try? await Task.sleep(for: .milliseconds(300))
                    if !Task.isCancelled { finishTodoDrag(move: false) }
                    return
                }
                let speed = TodoDrag.autoScrollSpeed(pointerY: pointerVY, viewportHeight: viewportH)
                if speed != 0, dropSlot != nil {
                    let y = min(max(scrollY + speed * 0.016, 0), scrollMax)
                    if y != scrollY {
                        todoScroll.scrollTo(y: y)
                        scrollY = y
                        updateSlot()
                    }
                }
                try? await Task.sleep(for: step)
            }
        }
    }

    private func finishTodoDrag(move: Bool) {
        if move, let id = draggingTodo, let slot = dropSlot { store.moveTodo(id, toSlot: slot) }
        autoScrollTask?.cancel()
        autoScrollTask = nil
        draggingTodo = nil
        dropSlot = nil
    }

    /// 「완료된 일 삭제 | ▾」. ▾ 목록은 시스템 메뉴 대신 서랍 안에 그려, 오른쪽 끝을 단추 오른쪽 끝에 맞춘다
    /// (시스템 메뉴는 화살표 왼쪽에서 시작해 서랍 밖으로 튀어나갔다).
    private var splitButton: some View {
        let h = rowHeight
        let shape = RoundedRectangle(cornerRadius: 5 * scale, style: .continuous)
        let none = store.document.completedCount == 0
        return HStack(spacing: 0) {
            Button {
                showClearMenu = false
                store.removeCompleted()
            } label: {
                Text("완료된 일 삭제")
                    .font(.system(size: DrawerFont.control * text))
                    .foregroundStyle(none ? .secondary : .primary)
                    .padding(.horizontal, 8 * scale)
                    .frame(height: h)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("체크된 할 일만 지우기")
            Rectangle().fill(palette.divider).frame(width: 1, height: h * 0.6)
            Button { showClearMenu.toggle() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9 * text, weight: .semibold))
                    .padding(.horizontal, 6 * scale)
                    .frame(height: h)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("더 보기")
        }
        .background(shape.fill(palette.tabFill))
        .fixedSize()
        .overlay(alignment: .topTrailing) {
            if showClearMenu {
                Button {
                    showClearMenu = false
                    confirmClearTodos = true
                } label: {
                    Text("할 일 비우기…")
                        .font(.system(size: 11.5 * text))
                        .foregroundStyle(store.document.todos.isEmpty ? .secondary : .primary)
                        .padding(.horizontal, 10 * scale)
                        .frame(height: h)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(store.document.todos.isEmpty)
                .background(RoundedRectangle(cornerRadius: 6 * scale, style: .continuous).fill(.regularMaterial))
                .overlay(RoundedRectangle(cornerRadius: 6 * scale, style: .continuous).stroke(palette.divider, lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                .fixedSize()
                .offset(y: h + 4 * scale)   // 단추 바로 아래, 오른쪽 끝 맞춤
            }
        }
    }

    /// 할 일 비우기 확인 줄(무엇을 지우는지 + 되돌릴 수 없음)
    private var clearTodosConfirm: some View {
        VStack(alignment: .leading, spacing: 4 * text) {
            Text("할 일 \(store.document.todos.count)개를 모두 지울까요? 되돌릴 수 없어요.")
                .font(.system(size: 11.5 * text, weight: .semibold))
            HStack {
                Spacer()
                Button("취소") { confirmClearTodos = false }
                Button("비우기", role: .destructive) {
                    confirmClearTodos = false
                    if model.todoEdit != nil { model.cancelTodoEdit() }
                    store.clearTodos()
                }
            }
            .font(.system(size: 11 * text))
            .controlSize(.small)
        }
        .padding(6 * scale)
        .background(RoundedRectangle(cornerRadius: 6 * scale).fill(Color.red.opacity(0.10)))
        .padding(.bottom, 2 * scale)
    }

    /// 이 줄을 고치는 중이면 고칠 글에 연결된 값, 아니면 nil
    private func editBinding(for item: TodoItem) -> Binding<String>? {
        guard model.todoEdit?.id == item.id else { return nil }
        return Binding(get: { model.todoEdit?.draft ?? item.text },
                       set: { model.todoEdit?.draft = $0 })
    }

    /// 입력줄 배경: 주변 유리보다 한 단계 밝게
    private var inputFill: Color {
        palette.dark ? Color.white.opacity(0.14) : Color.white.opacity(0.75)
    }

    private func add() {
        if store.addTodo(newTodo) { newTodo = "" }
        focus = .newTodo
    }
}

/// 할 일 한 줄(높이 22): 체크 · 글 · 마우스를 올리면 지우기 단추
struct TodoRow: View {
    let item: TodoItem
    let height: CGFloat
    let scale: CGFloat
    let text: CGFloat
    let palette: DrawerPalette
    /// 고치는 중이면 고칠 글
    let editDraft: Binding<String>?
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onBeginEdit: () -> Void
    let onCommitEdit: () -> Void
    /// 줄을 끌기 시작할 때
    let onDragStart: () -> Void
    /// 지금 끌려가는 줄이면 흐리게
    let dragging: Bool

    @State private var hovering = false
    @FocusState private var editFocused: Bool

    var body: some View {
        // 줄 전체를 끌어 순서를 바꾼다(고치는 중에는 글 칸 안 글자 끌기를 막지 않게 끔)
        if editDraft == nil {
            rowBody.onDrag {
                // 끌기가 시작되는 순간에 화면을 바꾸면 끌기가 취소될 수 있어 한 박자 뒤에 알린다.
                DispatchQueue.main.async { onDragStart() }
                let p = NSItemProvider()
                let data = Data(item.id.uuidString.utf8)
                p.registerDataRepresentation(forTypeIdentifier: UTType.topTiroirTodo.identifier,
                                             visibility: .ownProcess) { done in done(data, nil); return nil }
                return p
            } preview: {
                Text(item.text).font(.system(size: 12 * text)).lineLimit(1)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 5).fill(.regularMaterial))
            }
        } else {
            rowBody
        }
    }

    private var rowBody: some View {
        HStack(spacing: 6 * scale) {
            Button(action: onToggle) {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13 * text))
                    .foregroundStyle(item.done ? Brand.orange : palette.tabText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.done ? "완료 취소" : "완료")
            if let editDraft {
                // 고치기: 긴 글도 전체가 보이게 여러 줄로. ↩ 저장, esc 취소.
                TextField("할 일", text: editDraft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12 * text))
                    .lineLimit(1...6)
                    .focused($editFocused)
                    .onSubmit(onCommitEdit)
                    .padding(.horizontal, 4 * scale)
                    .padding(.vertical, 2 * scale)
                    .background(RoundedRectangle(cornerRadius: 4 * scale).fill(palette.dark ? Color.white.opacity(0.14) : Color.white.opacity(0.75)))
                    .overlay(RoundedRectangle(cornerRadius: 4 * scale).stroke(Brand.orange.opacity(0.7), lineWidth: 1))
                    .onAppear { editFocused = true }
            } else {
                Text(item.text)
                    .font(.system(size: 12 * text))
                    .strikethrough(item.done)
                    .foregroundStyle(item.done ? palette.tabText.opacity(0.7) : palette.selectedText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: onBeginEdit)
                    .help(String(localized: "\(item.text)\n(더블클릭하면 고치기, 끌어서 순서 바꾸기)"))
            }
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10 * text, weight: .semibold))
                    .foregroundStyle(palette.tabText)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .accessibilityLabel("목록에서 지우기")
            .help("목록에서 지우기")
        }
        .padding(.horizontal, 6 * scale)
        .frame(minHeight: height)
        .background(RoundedRectangle(cornerRadius: 4 * scale).fill(hovering ? palette.tabFill : .clear))
        .opacity(dragging ? 0.4 : 1)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

/// 끌어서 순서 바꾸기 전용 종류(메모·즐겨찾기가 받지 않게, 다른 앱으로는 나가지 않음)
extension UTType {
    static let topTiroirTodo = UTType(exportedAs: TodoDrag.reorderType)
}

/// 할 일 줄 위에 끌어 놓기: 위치를 알려 주고, 놓으면 순서를 바꾼다.
struct TodoDropDelegate: DropDelegate {
    /// 줄 안쪽 세로 위치
    let update: (CGFloat) -> Void
    let perform: () -> Void

    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.topTiroirTodo]) }
    func dropEntered(info: DropInfo) { update(info.location.y) }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        update(info.location.y)
        return DropProposal(operation: .move)
    }
    func performDrop(info: DropInfo) -> Bool {
        perform()
        return true
    }
}
