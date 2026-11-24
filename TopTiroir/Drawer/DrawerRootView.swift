import AppKit
import SwiftUI

/// 단추·선택 상자 글자 크기(× 글자 크기 설정). 「완료된 일 삭제」와 설정 탭 단추가 같이 쓴다.
enum DrawerFont {
    static let control: CGFloat = 11
}

enum Brand {
    static let black = Color(red: 11 / 255, green: 12 / 255, blue: 16 / 255)          // #0B0C10
    static let orange = Color(red: 245 / 255, green: 166 / 255, blue: 35 / 255)       // #F5A623
}

/// 시안의 라이트/다크 색. 숫자는 시안 값을 그대로 옮겼다.
struct DrawerPalette {
    let dark: Bool

    var glassTop: Color { dark ? Color(red: 62 / 255, green: 66 / 255, blue: 88 / 255, opacity: 0.62) : .white.opacity(0.70) }
    var glassBottom: Color { dark ? Color(red: 30 / 255, green: 32 / 255, blue: 46 / 255, opacity: 0.52) : .white.opacity(0.48) }
    var border: Color { .white.opacity(dark ? 0.2 : 0.8) }
    var divider: Color { dark ? .white.opacity(0.16) : .black.opacity(0.12) }
    var handle: Color { dark ? .white.opacity(0.3) : Color(red: 29 / 255, green: 29 / 255, blue: 31 / 255, opacity: 0.3) }

    var tabFill: Color { dark ? .white.opacity(0.08) : Color(red: 110 / 255, green: 115 / 255, blue: 135 / 255, opacity: 0.16) }
    var tabText: Color { dark ? Color(red: 185 / 255, green: 189 / 255, blue: 204 / 255) : Color(red: 74 / 255, green: 77 / 255, blue: 87 / 255) }
    var selectedFill: Color { .white.opacity(dark ? 0.22 : 0.95) }
    var selectedText: Color { dark ? .white : Color(red: 29 / 255, green: 29 / 255, blue: 31 / 255) }

    var sectionTitle: Color { tabText.opacity(0.85) }
    var popupFill: Color { tabFill }
}

/// 서랍 전체: 메뉴막대 아래에 매달린 유리판. 위에 책갈피 탭, 가운데 내용, 맨 아래 손잡이.
struct DrawerRootView: View {
    @Bindable var model: DrawerModel
    @AppStorage(SettingsKey.drawerScale) private var storedScale = SettingsDefault.drawerScale
    @Environment(\.colorScheme) private var scheme
    /// 끌기 시작할 때의 길이와 마우스 높이(화면 좌표)
    @State private var dragStart: (height: CGFloat, mouseY: CGFloat)?

    @AppStorage(SettingsKey.textScale) private var storedText = SettingsDefault.textScale
    @AppStorage(SettingsKey.drawerOpacity) private var storedWindowOpacity = SettingsDefault.drawerOpacity
    @AppStorage(SettingsKey.textOpacity) private var storedTextOpacity = SettingsDefault.textOpacity
    @AppStorage(SettingsKey.drawerColorMode) private var colorMode = SettingsDefault.drawerColorMode
    @AppStorage(SettingsKey.drawerColor) private var customColorHex = SettingsDefault.drawerColor

    /// 창 크기 비율(폭·여백·모서리·손잡이)
    private var s: CGFloat { CGFloat(Layout.clampedScale(storedScale)) }
    /// 글자 크기 비율(글자와 글자 줄 높이)
    private var t: CGFloat { CGFloat(Layout.clampedScale(storedText)) }
    /// 유리 배경 투명도(글자는 그대로). 슬라이드바를 끄는 동안엔 미리 보기 값.
    private var windowOpacity: Double {
        Layout.clampedOpacity(model.windowOpacityPreview ?? storedWindowOpacity, range: Layout.windowOpacityRange)
    }
    private var textOpacity: Double {
        Layout.clampedOpacity(model.textOpacityPreview ?? storedTextOpacity, range: Layout.textOpacityRange)
    }

    var body: some View {
        let palette = DrawerPalette(dark: scheme == .dark)
        let radius = 24 * s
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .continuous)
        let tabBarHeight = 17 * t                  // 선택 탭 16 + 가로선 1 (글자 크기를 따름)
        let handleArea = 4 * s + 16 * s            // 손잡이 + 위아래 여백
        let chrome = 10 * s + tabBarHeight + handleArea
        let available = max(model.maxHeight - chrome, 40)

        VStack(spacing: 0) {
            BookmarkTabBar(selection: $model.tab, scale: s, text: t, palette: palette)
                .frame(height: tabBarHeight)
            // 모든 탭이 같은 길이(손잡이로 정함). 내용이 길면 탭 안에서 스크롤.
            let contentMax = max(available - 6 * s, 0)
            let contentHeight = Layout.clampedNotesHeight(model.notesHeight, maxHeight: contentMax)
            Group {
                if model.tab == .notes {
                    NotesTabView(model: model, height: contentHeight, scale: s, text: t, palette: palette)
                } else {
                    ScrollView {
                        tabContent(palette, height: contentHeight)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(height: contentHeight + 6 * s)
                }
            }
            .overlay(alignment: .top) {
                // 화면 켜 두기가 자동으로 꺼진 이유(서랍을 닫으면 사라짐)
                if let notice = model.keepAwake.notice {
                    Text(notice)
                        .font(.system(size: 11 * t, weight: .medium))
                        .padding(.horizontal, 10 * s)
                        .padding(.vertical, 5 * s)
                        .background(Capsule().fill(.regularMaterial))
                        .overlay(Capsule().stroke(Brand.orange.opacity(0.7), lineWidth: 1))
                        .padding(.top, 8 * s)
                        .onTapGesture { model.keepAwake.notice = nil }
                        .help("눌러서 닫기")
                }
            }
            // 서랍이 열려 있는 동안 안내가 보이면 5초 뒤 저절로 사라진다(한 번만).
            .task(id: "\(model.isDrawerOpen)-\(model.keepAwake.notice ?? "")") {
                guard model.isDrawerOpen, model.keepAwake.notice != nil else { return }
                try? await Task.sleep(for: .seconds(5))
                if !Task.isCancelled { model.keepAwake.notice = nil }
            }
            handle(palette, maxHeight: contentMax)
        }
        .opacity(textOpacity)
        .overlay(alignment: .bottom) {
            if model.pendingAction != nil { saveEditPrompt(palette) }
        }
        .padding(.top, 10 * s)
        .padding(.horizontal, 12 * s)
        .frame(width: Layout.drawerWidth(scale: Double(s)))
        .background {
            ZStack {
                VisualEffectBlur()
                if colorMode == DrawerColorMode.custom.rawValue {
                    // 직접 고른 색을 바탕으로(투명도 설정과 함께)
                    Color(nsColor: NSColor(ttHex: customColorHex))
                } else {
                    LinearGradient(colors: [palette.glassTop, palette.glassBottom], startPoint: .top, endPoint: .bottom)
                }
            }
            .opacity(windowOpacity)
        }
        .clipShape(shape)
        .overlay {
            OpenTopOutline(radius: radius).stroke(palette.border.opacity(windowOpacity), lineWidth: 1)
        }
    }

    /// 맨 아래 손잡이: 모든 탭에서 위아래로 끌어 서랍 길이를 바꾼다(한 값을 같이 씀). 메모/할 일 탭에선 왼쪽에 남은 할 일 수.
    @ViewBuilder private func handle(_ palette: DrawerPalette, maxHeight: CGFloat) -> some View {
        let bar = Capsule()
            .fill(dragStart != nil ? Brand.orange.opacity(0.8) : palette.handle)
            .frame(width: 36 * s, height: 4 * s)
            .padding(.vertical, 8 * s)
            .padding(.horizontal, 40 * s)   // 끌 수 있는 범위(가운데만, 왼쪽 글자와 겹치지 않게)
            .contentShape(Rectangle())
        ZStack {
            if model.tab == .notes {
                HStack {
                    Text(todoCountText)
                        .font(.system(size: 10.5 * t).monospacedDigit())
                        .foregroundStyle(palette.sectionTitle)
                        .help("남은 할 일 / 전체 할 일")
                    Spacer()
                }
                .padding(.leading, 6 * s)
            }
            bar
                    .pointerStyle(.frameResize(position: .bottom))
                    .help("끌어서 길이 바꾸기")
                    .gesture(
                        // 서랍 창이 함께 늘어나므로 창 안 좌표 대신 화면의 마우스 위치로 계산한다.
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { _ in
                                let mouseY = NSEvent.mouseLocation.y
                                if dragStart == nil {
                                    dragStart = (Layout.clampedNotesHeight(model.notesHeight, maxHeight: maxHeight), mouseY)
                                }
                                guard let start = dragStart else { return }
                                let h = Layout.notesHeightAfterDrag(startHeight: start.height, startMouseY: start.mouseY,
                                                                    currentMouseY: mouseY, maxHeight: maxHeight)
                                model.setNotesHeight(h, save: false)
                            }
                            .onEnded { _ in
                                dragStart = nil
                                model.setNotesHeight(model.notesHeight, save: true)
                            }
                    )
        }
        .frame(maxWidth: .infinity)
    }

    /// 할 일을 고친 채 닫기·종료하려 할 때 서랍 안에 띄우는 확인 줄
    private func saveEditPrompt(_ palette: DrawerPalette) -> some View {
        let quitting = model.pendingAction == .quit
        return VStack(alignment: .leading, spacing: 6 * t) {
            Text("수정한 내용을 저장할까요?")
                .font(.system(size: 12 * t, weight: .semibold))
            Text(quitting ? "고른 뒤 TopTiroir를 종료해요." : "고른 뒤 서랍을 닫아요.")
                .font(.system(size: 11 * t))
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("취소") { model.resolvePending(save: nil) }
                Button("저장 안 함") { model.resolvePending(save: false) }
                Button("저장") { model.resolvePending(save: true) }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.orange)
            }
            .font(.system(size: 11 * t))
            .controlSize(.small)
        }
        .padding(10 * s)
        .background(RoundedRectangle(cornerRadius: 10 * s, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 10 * s, style: .continuous).stroke(Brand.orange.opacity(0.6), lineWidth: 1))
        .padding(.bottom, 24 * s)
    }

    private var todoCountText: String {
        let d = model.notes.document
        return d.todos.isEmpty ? "" : "미완료 \(d.remainingCount) / 할 일 \(d.todos.count)"
    }

    @ViewBuilder private func tabContent(_ palette: DrawerPalette, height: CGFloat) -> some View {
        switch model.tab {
        case .notes: EmptyView()
        case .favorites: FavoritesTabView(model: model, scale: s, text: t, palette: palette, minHeight: height)
        case .settings: SettingsTabView(model: model, scale: s, text: t, palette: palette)
        }
    }
}

/// 뒤가 흐리게 비치는 배경. 서랍이 비활성 상태여도 항상 흐림이 보이게 한다.
struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// 위쪽만 뚫린 테두리(왼쪽 → 아래 둥근 모서리 → 오른쪽)
struct OpenTopOutline: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width / 2, rect.height / 2)
        let inset = rect.insetBy(dx: 0.5, dy: 0.5)
        var p = Path()
        p.move(to: CGPoint(x: inset.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: inset.minX, y: inset.maxY - r))
        p.addArc(tangent1End: CGPoint(x: inset.minX, y: inset.maxY), tangent2End: CGPoint(x: inset.minX + r, y: inset.maxY), radius: r)
        p.addLine(to: CGPoint(x: inset.maxX - r, y: inset.maxY))
        p.addArc(tangent1End: CGPoint(x: inset.maxX, y: inset.maxY), tangent2End: CGPoint(x: inset.maxX, y: inset.maxY - r), radius: r)
        p.addLine(to: CGPoint(x: inset.maxX, y: rect.minY))
        return p
    }
}

/// 위쪽 두 모서리가 둥근 탭의 테두리(아래쪽 변은 그리지 않아 내용과 이어져 보인다)
struct TabOutline: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width / 2, rect.height)
        let inset = rect.insetBy(dx: 0.5, dy: 0.5)
        var p = Path()
        p.move(to: CGPoint(x: inset.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: inset.minX, y: inset.minY + r))
        p.addArc(tangent1End: CGPoint(x: inset.minX, y: inset.minY), tangent2End: CGPoint(x: inset.minX + r, y: inset.minY), radius: r)
        p.addLine(to: CGPoint(x: inset.maxX - r, y: inset.minY))
        p.addArc(tangent1End: CGPoint(x: inset.maxX, y: inset.minY), tangent2End: CGPoint(x: inset.maxX, y: inset.minY + r), radius: r)
        p.addLine(to: CGPoint(x: inset.maxX, y: rect.maxY))
        return p
    }
}

/// 책갈피 탭 3개: 폭을 똑같이 나누고, 선택된 탭은 2pt 더 높아 아래 가로선을 덮는다.
struct BookmarkTabBar: View {
    @Binding var selection: DrawerTab
    let scale: CGFloat
    let text: CGFloat
    let palette: DrawerPalette

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(palette.divider)
                .frame(height: 1)
            HStack(alignment: .bottom, spacing: 3 * scale) {
                ForEach(DrawerTab.allCases) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, 6 * scale)
        }
    }

    private func tabButton(_ tab: DrawerTab) -> some View {
        let selected = tab == selection
        let r = 7 * scale
        let shape = UnevenRoundedRectangle(topLeadingRadius: r, topTrailingRadius: r)
        return Button { selection = tab } label: {
            Text(tab.title)
                .font(.system(size: 12 * text, weight: selected ? .bold : .semibold))
                .foregroundStyle(selected ? palette.selectedText : palette.tabText)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                // 선택: 16pt + 가로선 1pt를 덮음 / 기본: 14pt, 가로선 위에 놓임
                .frame(height: selected ? 17 * text : 14 * text)
                .padding(.bottom, selected ? 0 : 1)
                .background {
                    if selected {
                        shape.fill(palette.selectedFill)
                            .shadow(color: palette.dark ? .clear : .black.opacity(0.10), radius: 1.5, x: 0, y: -1)
                            .overlay(alignment: .top) {
                                if palette.dark {
                                    // 다크: 위쪽 1pt 안쪽 하이라이트
                                    shape.stroke(Color.white.opacity(0.25), lineWidth: 1)
                                        .mask(alignment: .top) { Rectangle().frame(height: r) }
                                }
                            }
                            .overlay { TabOutline(radius: r).stroke(palette.divider, lineWidth: 1) }
                    } else {
                        shape.fill(palette.tabFill).padding(.bottom, 1)
                    }
                }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .zIndex(selected ? 1 : 0)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ComingSoonView: View {
    let symbol: String
    let text: String
    let scale: CGFloat
    let textScale: CGFloat
    let palette: DrawerPalette

    var body: some View {
        VStack(spacing: 8 * scale) {
            Image(systemName: symbol)
                .font(.system(size: 22 * scale))
                .foregroundStyle(Brand.orange)
            Text(text)
                .font(.system(size: 12 * textScale))
                .foregroundStyle(palette.tabText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28 * scale)
    }
}
