import AppKit
import SwiftUI

/// 설정 탭: 화면 / 동작 / 관리 세 구역
struct SettingsTabView: View {
    let model: DrawerModel
    /// 창 크기 비율(폭·여백·컨트롤 폭)
    let scale: CGFloat
    /// 글자 크기 비율(글자·줄 높이·작은 컨트롤)
    let text: CGFloat
    let palette: DrawerPalette

    @AppStorage(SettingsKey.hideNotch) private var hideNotch = SettingsDefault.hideNotch
    @AppStorage(SettingsKey.roundCorners) private var roundCorners = SettingsDefault.roundCorners
    @AppStorage(SettingsKey.bandColor) private var bandColorHex = SettingsDefault.bandColor
    @AppStorage(SettingsKey.drawerScale) private var drawerScale = SettingsDefault.drawerScale
    @AppStorage(SettingsKey.notchOpenMode) private var notchOpenMode = SettingsDefault.notchOpenMode
    @AppStorage(SettingsKey.closeMode) private var closeMode = SettingsDefault.closeMode
    @AppStorage(SettingsKey.drawerOpacity) private var drawerOpacity = SettingsDefault.drawerOpacity
    @AppStorage(SettingsKey.openTabMode) private var openTabMode = SettingsDefault.openTabMode
    @AppStorage(SettingsKey.textScale) private var textScale = SettingsDefault.textScale
    @AppStorage(SettingsKey.textOpacity) private var textOpacity = SettingsDefault.textOpacity
    @AppStorage(SettingsKey.indentWidth) private var indentWidth = SettingsDefault.indentWidth
    @AppStorage(SettingsKey.drawerColorMode) private var drawerColorMode = SettingsDefault.drawerColorMode
    @AppStorage(SettingsKey.drawerAppearance) private var drawerAppearance = SettingsDefault.drawerAppearance
    @AppStorage(SettingsKey.drawerColor) private var drawerColorHex = SettingsDefault.drawerColor
    @State private var indentText = ""

    /// 비우기 확인 중인 대상
    @State private var confirmClear: ClearTarget?
    @State private var clearMessage: String?
    @State private var loginEnabled = LoginItem.isEnabled
    @State private var loginMessage: String?
    @State private var statusItemShown = false

    private var font: Font { .system(size: 12 * text) }

    /// 단추 글자: 「완료된 일 삭제」와 같은 값(DrawerFont.control × 글자 크기)
    private var controlFont: Font { .system(size: DrawerFont.control * text) }

    /// 선택 상자(글꼴을 직접 못 정함)는 크기 단계로 맞춘다: small = 11pt. 글자 크기를 줄이면 mini, 키우면 regular.
    private var controlSize: ControlSize {
        switch text {
        case ..<0.9: .mini
        case ..<1.2: .small
        default: .regular
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            section("화면") {
                row("노치 숨기기") { toggle($hideNotch) }
                row("화면 모서리 둥글게") { toggle($roundCorners) }
                row("띠 색") {
                    Button { model.onShowColorPanel?(SettingsKey.bandColor, SettingsDefault.bandColor) } label: {
                        RoundedRectangle(cornerRadius: 4 * scale)
                            .fill(Color(nsColor: NSColor(ttHex: bandColorHex)))
                            .overlay(RoundedRectangle(cornerRadius: 4 * scale).stroke(palette.divider, lineWidth: 1))
                            .frame(width: 34 * scale, height: 15 * scale)
                    }
                    .buttonStyle(.plain)
                    .help("띠 색 고르기 (\(bandColorHex))")
                    if bandColorHex != SettingsDefault.bandColor {
                        Button("기본") { bandColorHex = SettingsDefault.bandColor }.font(controlFont)
                    }
                }
                row("서랍·창 색상") { drawerColorControl }
                row("글자 크기") {
                    PercentSlider(stored: $textScale, range: Layout.scaleRange, step: 0.1,
                                  clamp: Layout.clampedScale, label: Layout.percentText,
                                  scale: scale, font: font)
                }
                row("서랍·창 크기") {
                    PercentSlider(stored: $drawerScale, range: Layout.scaleRange, step: 0.1,
                                  clamp: Layout.clampedScale, label: Layout.percentText,
                                  scale: scale, font: font)
                }
                row("글자 투명도") {
                    PercentSlider(stored: $textOpacity, range: Layout.textOpacityRange, step: 0.05,
                                  clamp: { Layout.clampedOpacity($0, range: Layout.textOpacityRange) },
                                  label: { Layout.opacityPercentText($0, range: Layout.textOpacityRange) },
                                  scale: scale, font: font,
                                  onPreview: { model.textOpacityPreview = $0 })
                }
                row("서랍·창 투명도") {
                    PercentSlider(stored: $drawerOpacity, range: Layout.windowOpacityRange, step: 0.05,
                                  clamp: { Layout.clampedOpacity($0, range: Layout.windowOpacityRange) },
                                  label: { Layout.opacityPercentText($0, range: Layout.windowOpacityRange) },
                                  scale: scale, font: font,
                                  onPreview: { model.windowOpacityPreview = $0 })
                }
            }
            Divider()
            section("동작") {
                row("들여쓰기 너비") { indentControl }
                row("노치에서 열기") {
                    Picker("노치에서 열기", selection: $notchOpenMode) {
                        ForEach(NotchOpenMode.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                }
                row("열 때 보여 줄 탭") {
                    Picker("열 때 보여 줄 탭", selection: $openTabMode) {
                        ForEach(OpenTabMode.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                }
                row("서랍 닫기") {
                    Picker("서랍 닫기", selection: $closeMode) {
                        ForEach(CloseMode.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                }
                row("단축키") {
                    Button(model.shortcutsWindowOpen ? "단축키 닫기" : "단축키 보기…") {
                        model.onToggleShortcutsWindow?()
                    }
                    .font(font)
                    
                    .font(controlFont)
                    .help("쓸 수 있는 단축키를 보고 바꾸는 창을 서랍 옆에 열어요")
                }
            }
            Divider()
            section("관리") {
                clearRow(.memo)
                if let clearMessage { note(clearMessage) }
                row("메뉴막대 아이콘 잠깐 보이기") {
                    Button(statusItemShown ? "60초 동안 보임" : "보이기") {
                        model.onShowStatusItem?()
                        statusItemShown = true
                    }
                    .font(controlFont)
                }
                row("로그인할 때 자동 실행") {
                    Toggle("로그인할 때 자동 실행", isOn: $loginEnabled)
                        .labelsHidden().toggleStyle(OrangeSwitchStyle(scale: text))
                        .onChange(of: loginEnabled) { _, newValue in setLogin(newValue) }
                }
                if let loginMessage {
                    Text(loginMessage)
                        .font(.system(size: 11 * text))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2 * scale)
                }
                row("TopTiroir 정보") {
                    Text("버전 \(Self.version)").font(font).foregroundStyle(.secondary)
                }
                row("TopTiroir 종료") {
                    HStack(spacing: 6 * scale) {
                        Text("⌘Q").font(font).foregroundStyle(.secondary)
                        // ⌘Q는 서랍이 열려 있으면 어느 탭에서든 동작(DrawerController 키 감시)
                        Button("종료") { NSApp.terminate(nil) }.font(controlFont)
                    }
                }
            }
        }
        .controlSize(controlSize)
        .padding(.horizontal, 6 * scale)
        .padding(.top, 4 * scale)
        .onAppear { refreshLogin() }
    }

    private func note(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 11 * text))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 2 * scale)
    }

    // MARK: 서랍·창 색상

    /// (●기본 [라이트/다크/시스템]) (○색상 [견본]) — 둘 중 하나만 고른다.
    private var drawerColorControl: some View {
        let mode = DrawerColorMode(rawValue: drawerColorMode) ?? .standard
        return HStack(spacing: 6 * scale) {
            radio(.standard, selected: mode == .standard)
            Picker("서랍 밝기", selection: $drawerAppearance) {
                ForEach(DrawerAppearance.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
            }
            .labelsHidden().pickerStyle(.menu).fixedSize()
            .disabled(mode != .standard)
            radio(.custom, selected: mode == .custom)
                .padding(.leading, 4 * scale)
            Button {
                drawerColorMode = DrawerColorMode.custom.rawValue
                model.onShowColorPanel?(SettingsKey.drawerColor, SettingsDefault.drawerColor)
            } label: {
                RoundedRectangle(cornerRadius: 4 * scale)
                    .fill(Color(nsColor: NSColor(ttHex: drawerColorHex)))
                    .overlay(RoundedRectangle(cornerRadius: 4 * scale).stroke(palette.divider, lineWidth: 1))
                    .frame(width: 26 * scale, height: 15 * text)
            }
            .buttonStyle(.plain)
            .opacity(mode == .custom ? 1 : 0.5)
            .help("서랍 색 고르기 (\(drawerColorHex))")
        }
    }

    private func radio(_ value: DrawerColorMode, selected: Bool) -> some View {
        Button { drawerColorMode = value.rawValue } label: {
            HStack(spacing: 3 * scale) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Brand.orange : .secondary)
                Text(value.title).lineLimit(1)
            }
            .font(.system(size: 11.5 * text))
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: 들여쓰기 너비

    /// + [ 4 칸 ] −  (1~8칸, 메모 칸 Tab 간격)
    private var indentControl: some View {
        HStack(spacing: 4 * scale) {
            Button("+") { setIndent(indentWidth + 1) }
                .font(controlFont)
                .disabled(indentWidth >= Indent.widthRange.upperBound)
                .help("한 칸 늘리기")
            HStack(spacing: 2 * scale) {
                TextField("", text: $indentText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(font.monospacedDigit())
                    .frame(width: 22 * text)
                    .lineLimit(1)
                    .onSubmit { applyIndentText() }
                Text("칸").font(font).fixedSize()
            }
            .padding(.horizontal, 5 * scale)
            .background(RoundedRectangle(cornerRadius: 4 * scale).fill(.quaternary))
            Button("−") { setIndent(indentWidth - 1) }
                .font(controlFont)
                .disabled(indentWidth <= Indent.widthRange.lowerBound)
                .help("한 칸 줄이기")
        }
        .onAppear { indentText = String(Indent.clampedWidth(indentWidth)) }
        .onChange(of: indentText) { _, new in
            // 숫자를 칠 때마다 반영(엉뚱한 글자는 무시하고 ↩ 때 되돌림)
            if let n = Indent.parsedWidth(new), n != indentWidth { indentWidth = n }
        }
    }

    private func setIndent(_ value: Int) {
        indentWidth = Indent.clampedWidth(value)
        indentText = String(indentWidth)
    }

    private func applyIndentText() {
        setIndent(Indent.parsedWidth(indentText) ?? indentWidth)
    }

    // MARK: 비우기

    enum ClearTarget { case memo, todos }

    /// 「비우기」 → 그 자리에 확인 줄(무엇을 지우는지, 되돌릴 수 없음) → 「비우기」를 한 번 더 눌러야 지운다.
    @ViewBuilder private func clearRow(_ target: ClearTarget) -> some View {
        let title = target == .memo ? "메모장 비우기" : "할 일 비우기"
        if confirmClear == target {
            VStack(alignment: .leading, spacing: 4 * text) {
                Text(target == .memo
                     ? "메모 글을 모두 지울까요? 되돌릴 수 없어요."
                     : "할 일 \(model.notes.document.todos.count)개를 모두 지울까요? 되돌릴 수 없어요.")
                    .font(.system(size: 11.5 * text, weight: .semibold))
                HStack {
                    Spacer()
                    Button("취소") { confirmClear = nil }
                    Button("비우기", role: .destructive) { clear(target) }
                }
            }
            .padding(6 * scale)
            .background(RoundedRectangle(cornerRadius: 6 * scale).fill(Color.red.opacity(0.10)))
            .padding(.vertical, 2 * text)
        } else {
            row(title) {
                Button("비우기") {
                    clearMessage = nil
                    confirmClear = target
                }
                .font(controlFont)
                .disabled(target == .memo ? model.notes.document.memo.isEmpty : model.notes.document.todos.isEmpty)
            }
        }
    }

    private func clear(_ target: ClearTarget) {
        confirmClear = nil
        let ok = target == .memo ? model.notes.clearMemo() : model.notes.clearTodos()
        clearMessage = ok ? nil : "백업 파일을 만들지 못해 지우지 않았어요."
    }

    // MARK: 줄·구역

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10.5 * text, weight: .bold))
                .foregroundStyle(palette.sectionTitle)
                .padding(.top, 6 * scale)
                .padding(.bottom, 2 * scale)
            content()
        }
        .padding(.bottom, 4 * scale)
    }

    /// 한 줄에 안 들어가면(글자가 크고 서랍이 좁을 때) 이름 아래 줄에 오른쪽 맞춰 놓는다.
    private func row<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        let c = control()
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 8 * scale) {
                Text(label).font(font).lineLimit(1).fixedSize()
                Spacer(minLength: 8 * scale)
                c.fixedSize()
            }
            VStack(alignment: .leading, spacing: 2 * text) {
                Text(label).font(font).lineLimit(1)
                HStack {
                    Spacer(minLength: 0)
                    c
                }
            }
        }
        .frame(minHeight: 21 * text)
    }

    private func toggle(_ binding: Binding<Bool>) -> some View {
        Toggle("", isOn: binding).labelsHidden().toggleStyle(OrangeSwitchStyle(scale: text))
    }

    // MARK: 값 연결

    private func refreshLogin() {
        loginEnabled = LoginItem.isEnabled
        loginMessage = LoginItem.status == .requiresApproval
            ? "시스템 설정 → 일반 → 로그인 항목에서 TopTiroir를 허용해 주세요." : nil
    }

    private func setLogin(_ enabled: Bool) {
        guard enabled != LoginItem.isEnabled else { return }
        do {
            try LoginItem.set(enabled)
            refreshLogin()
        } catch {
            loginMessage = "자동 실행을 바꾸지 못했어요: \(error.localizedDescription)"
            loginEnabled = LoginItem.isEnabled
        }
    }

    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
}

/// 퍼센트 슬라이드바. 손을 떼면 저장한다.
/// onPreview가 있으면(투명도) 끄는 동안 바로 보여 주고, 손을 떼거나 0.4초 멈추면 저장한다.
/// onPreview가 없으면(크기) 끄는 동안 서랍 크기가 바뀌어 손에서 도망가지 않게 손을 뗄 때만 저장한다.
struct PercentSlider: View {
    @Binding var stored: Double
    let range: ClosedRange<Double>
    let step: Double
    let clamp: (Double) -> Double
    let label: (Double) -> String
    let scale: CGFloat
    let font: Font
    var onPreview: ((Double?) -> Void)?

    @State private var draft: Double?
    @State private var commitTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 6 * scale) {
            Slider(value: binding, in: range, step: step) { editing in
                if !editing { commit() }
            }
            .tint(Brand.orange)
            .frame(width: 120 * scale)
            Text(label(draft ?? stored))
                .font(font).monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: 38 * scale, alignment: .trailing)
        }
    }

    private var binding: Binding<Double> {
        Binding(get: { draft ?? stored }, set: { value in
            draft = value
            guard let onPreview else { return }
            onPreview(value)
            commitTask?.cancel()
            commitTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                commit()
            }
        })
    }

    private func commit() {
        commitTask?.cancel()
        commitTask = nil
        guard let d = draft else { return }
        stored = clamp(d)
        draft = nil
        onPreview?(nil)
    }
}

/// 시안 스위치: 약 26×15pt, 켜짐은 주황 #F5A623
struct OrangeSwitchStyle: ToggleStyle {
    let scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        let w = 26 * scale, h = 15 * scale, knob = h - 3 * scale
        Button { configuration.isOn.toggle() } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Brand.orange : Color.gray.opacity(0.35))
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.25), radius: 0.5, y: 0.5)
                    .frame(width: knob, height: knob)
                    .padding(1.5 * scale)
            }
            .frame(width: w, height: h)
            .animation(.easeOut(duration: 0.12), value: configuration.isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "켬" : "끔")
    }
}
