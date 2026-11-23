import SwiftUI

/// 단축키 보기 창: 서랍 옆에 붙는 유리 창. 바꿀 수 있는 키는 줄을 눌러 바꾸고, 편집 키는 보기만.
struct ShortcutsView: View {
    @Bindable var model: DrawerModel
    @Environment(\.colorScheme) private var scheme

    @AppStorage(SettingsKey.drawerScale) private var storedScale = SettingsDefault.drawerScale
    @AppStorage(SettingsKey.textScale) private var storedText = SettingsDefault.textScale
    @AppStorage(SettingsKey.drawerOpacity) private var storedWindowOpacity = SettingsDefault.drawerOpacity
    @AppStorage(SettingsKey.textOpacity) private var storedTextOpacity = SettingsDefault.textOpacity
    @AppStorage(SettingsKey.drawerColorMode) private var colorMode = SettingsDefault.drawerColorMode
    @AppStorage(SettingsKey.drawerColor) private var customColorHex = SettingsDefault.drawerColor

    private var s: CGFloat { CGFloat(Layout.clampedScale(storedScale)) }
    private var t: CGFloat { CGFloat(Layout.clampedScale(storedText)) }

    var body: some View {
        let palette = DrawerPalette(dark: scheme == .dark)
        let shape = RoundedRectangle(cornerRadius: 16 * s, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("단축키")
                    .font(.system(size: 13 * t, weight: .bold))
                Spacer()
                Button { model.onToggleShortcutsWindow?() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14 * t))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("닫기")
            }
            .padding(.bottom, 6 * s)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    section("서랍", palette) {
                        editable(.openDrawer, palette)
                        ForEach(FixedShortcut.drawer, id: \.title) { fixed($0, palette) }
                        editable(.quit, palette)
                    }
                    section("탭 이동", palette) {
                        editable(.tabNotes, palette)
                        editable(.tabFavorites, palette)
                        editable(.tabSettings, palette)
                        Text("기능 키(F1~F12)나 ⌘·⌃ 조합은 언제나 동작해요. 글자·숫자 한 키로 바꾸면 글자 커서가 없을 때만 동작해요(입력칸에선 글자로 들어가요).")
                            .font(.system(size: 10.5 * t))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2 * s)
                    }
                    section("메모·할 일 편집 (바꿀 수 없음)", palette) {
                        ForEach(FixedShortcut.editing, id: \.title) { fixed($0, palette) }
                    }
                    Text("입력칸이 아닌 곳을 누르면 글자 커서가 빠져요.")
                        .font(.system(size: 10.5 * t))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8 * s)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            HStack {
                Spacer()
                Button("모두 초기화") { model.resetAll() }
                    .disabled(model.shortcuts.isAllDefault)
                    .font(.system(size: 11 * t))
                    .controlSize(.small)
            }
            .padding(.top, 6 * s)
        }
        .opacity(Layout.clampedOpacity(model.textOpacityPreview ?? storedTextOpacity, range: Layout.textOpacityRange))
        .padding(12 * s)
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
            .opacity(Layout.clampedOpacity(model.windowOpacityPreview ?? storedWindowOpacity,
                                           range: Layout.windowOpacityRange))
        }
        .clipShape(shape)
        .overlay(shape.stroke(palette.border.opacity(0.6), lineWidth: 1))
    }

    private func section<Content: View>(_ title: String, _ palette: DrawerPalette,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10.5 * t, weight: .bold))
                .foregroundStyle(palette.sectionTitle)
                .padding(.top, 6 * s)
                .padding(.bottom, 2 * s)
            content()
        }
    }

    /// 바꿀 수 있는 줄: 키 단추를 누르면 「새 키를 누르세요…」
    private func editable(_ action: ShortcutAction, _ palette: DrawerPalette) -> some View {
        let recording = model.recordingAction == action
        let message = model.shortcutMessage?.action == action ? model.shortcutMessage?.text : nil
        return VStack(alignment: .leading, spacing: 1 * t) {
            HStack(spacing: 6 * s) {
                Text(action.title).font(.system(size: 12 * t))
                Spacer(minLength: 4 * s)
                if !model.shortcuts.isDefault(action) && !recording {
                    Button("초기화") { model.reset(action) }
                        .font(.system(size: 10.5 * t))
                        .controlSize(.mini)
                        .help("기본값 \(action.defaultShortcut.displayName)으로")
                }
                Button { model.beginRecording(action) } label: {
                    Text(recording ? "새 키를 누르세요…" : keyTitle(action))
                        .font(.system(size: 11 * t, weight: .medium))
                        .foregroundStyle(recording ? Color.white : Color.primary)
                        .padding(.horizontal, 6 * s)
                        .padding(.vertical, 1 * t)
                        .background(RoundedRectangle(cornerRadius: 4 * s)
                            .fill(recording ? AnyShapeStyle(Brand.orange) : AnyShapeStyle(.quaternary)))
                }
                .buttonStyle(.plain)
                .help(recording ? "esc 또는 다시 누르면 취소" : "눌러서 바꾸기")
            }
            .frame(minHeight: 21 * t)
            if let message {
                Text(message)
                    .font(.system(size: 10.5 * t))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if recording {
                Text("새 키를 누르세요. esc를 누르면 취소돼요.")
                    .font(.system(size: 10.5 * t))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func keyTitle(_ action: ShortcutAction) -> String {
        let name = model.shortcuts[action].displayName
        return action == .openDrawer && !model.hotKeyAvailable ? "\(name) (사용 불가)" : name
    }

    /// 보기 전용 줄(흐리게)
    private func fixed(_ item: FixedShortcut, _ palette: DrawerPalette) -> some View {
        HStack(spacing: 6 * s) {
            Text(item.title).font(.system(size: 12 * t))
            Spacer(minLength: 4 * s)
            Text(item.keys)
                .font(.system(size: 11 * t, weight: .medium))
                .padding(.horizontal, 6 * s)
                .padding(.vertical, 1 * t)
                .overlay(RoundedRectangle(cornerRadius: 4 * s).stroke(palette.divider, lineWidth: 1))
        }
        .foregroundStyle(.secondary)
        .frame(minHeight: 21 * t)
        .help("바꿀 수 없음")
    }
}
