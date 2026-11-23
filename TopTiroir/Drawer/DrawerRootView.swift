import AppKit
import SwiftUI

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

    private var s: CGFloat { CGFloat(Layout.clampedScale(storedScale)) }

    var body: some View {
        let palette = DrawerPalette(dark: scheme == .dark)
        let radius = 24 * s
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .continuous)
        let tabBarHeight = 17 * s                  // 선택 탭 16 + 가로선 1
        let handleArea = 4 * s + 16 * s            // 손잡이 + 위아래 여백
        let chrome = 10 * s + tabBarHeight + handleArea
        let available = max(model.maxHeight - chrome, 40)

        VStack(spacing: 0) {
            BookmarkTabBar(selection: $model.tab, scale: s, palette: palette)
                .frame(height: tabBarHeight)
            ScrollView {
                tabContent(palette)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { model.reportContentHeight($0) }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(model.contentHeight, available))
            Capsule()
                .fill(palette.handle)
                .frame(width: 36 * s, height: 4 * s)
                .padding(.vertical, 8 * s)
        }
        .padding(.top, 10 * s)
        .padding(.horizontal, 12 * s)
        .frame(width: Layout.drawerWidth(scale: Double(s)))
        .background {
            ZStack {
                VisualEffectBlur()
                LinearGradient(colors: [palette.glassTop, palette.glassBottom], startPoint: .top, endPoint: .bottom)
            }
        }
        .clipShape(shape)
        .overlay {
            OpenTopOutline(radius: radius).stroke(palette.border, lineWidth: 1)
        }
    }

    @ViewBuilder private func tabContent(_ palette: DrawerPalette) -> some View {
        switch model.tab {
        case .notes: ComingSoonView(symbol: "note.text", text: "메모/할 일은 v0.2에서 만나요", scale: s, palette: palette)
        case .favorites: ComingSoonView(symbol: "star", text: "즐겨찾기는 v0.4에서 만나요", scale: s, palette: palette)
        case .settings: SettingsTabView(model: model, scale: s, palette: palette)
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
                .font(.system(size: 12 * scale, weight: selected ? .bold : .semibold))
                .foregroundStyle(selected ? palette.selectedText : palette.tabText)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                // 선택: 16pt + 가로선 1pt를 덮음 / 기본: 14pt, 가로선 위에 놓임
                .frame(height: selected ? 17 * scale : 14 * scale)
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
    let palette: DrawerPalette

    var body: some View {
        VStack(spacing: 8 * scale) {
            Image(systemName: symbol)
                .font(.system(size: 22 * scale))
                .foregroundStyle(Brand.orange)
            Text(text)
                .font(.system(size: 12 * scale))
                .foregroundStyle(palette.tabText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28 * scale)
    }
}
