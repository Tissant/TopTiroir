import AppKit
import SwiftUI

/// 설정 탭: 화면 / 동작 / 관리 세 구역
struct SettingsTabView: View {
    let model: DrawerModel
    let scale: CGFloat
    let palette: DrawerPalette

    @AppStorage(SettingsKey.hideNotch) private var hideNotch = SettingsDefault.hideNotch
    @AppStorage(SettingsKey.roundCorners) private var roundCorners = SettingsDefault.roundCorners
    @AppStorage(SettingsKey.bandColor) private var bandColorHex = SettingsDefault.bandColor
    @AppStorage(SettingsKey.drawerScale) private var drawerScale = SettingsDefault.drawerScale
    @AppStorage(SettingsKey.notchOpenMode) private var notchOpenMode = SettingsDefault.notchOpenMode
    @AppStorage(SettingsKey.closeMode) private var closeMode = SettingsDefault.closeMode

    @State private var scaleDraft: Double?
    @State private var loginEnabled = LoginItem.isEnabled
    @State private var loginMessage: String?
    @State private var statusItemShown = false

    private var font: Font { .system(size: 12 * scale) }

    /// 크기 비율에 맞춘 팝업·버튼 크기(시안: 작은 컨트롤)
    private var controlSize: ControlSize {
        switch scale {
        case ..<1.05: .mini
        case ..<1.35: .small
        default: .regular
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            section("화면") {
                row("노치 숨기기") { toggle($hideNotch) }
                row("화면 모서리 둥글게") { toggle($roundCorners) }
                row("띠 색") {
                    Button { model.onShowColorPanel?() } label: {
                        RoundedRectangle(cornerRadius: 4 * scale)
                            .fill(Color(nsColor: NSColor(ttHex: bandColorHex)))
                            .overlay(RoundedRectangle(cornerRadius: 4 * scale).stroke(palette.divider, lineWidth: 1))
                            .frame(width: 34 * scale, height: 15 * scale)
                    }
                    .buttonStyle(.plain)
                    .help("띠 색 고르기 (\(bandColorHex))")
                    if bandColorHex != SettingsDefault.bandColor {
                        Button("기본") { bandColorHex = SettingsDefault.bandColor }
                    }
                }
                row("서랍·창 크기") {
                    HStack(spacing: 6 * scale) {
                        Slider(value: scaleBinding, in: Layout.scaleRange, step: 0.1) { editing in
                            if !editing, let d = scaleDraft {
                                drawerScale = Layout.clampedScale(d)
                                scaleDraft = nil
                            }
                        }
                        .tint(Brand.orange)
                        .frame(width: 120 * scale)
                        Text(Layout.percentText(scaleDraft ?? drawerScale))
                            .font(font).monospacedDigit()
                            .frame(width: 38 * scale, alignment: .trailing)
                    }
                }
            }
            Divider()
            section("동작") {
                row("서랍 열기 단축키") {
                    Text(model.hotKeyAvailable ? "F12" : "F12 (다른 앱이 사용 중)")
                        .font(.system(size: 11 * scale, weight: .medium))
                        .padding(.horizontal, 6 * scale)
                        .padding(.vertical, 1 * scale)
                        .background(RoundedRectangle(cornerRadius: 4 * scale).fill(.quaternary))
                }
                row("노치에서 열기") {
                    Picker("노치에서 열기", selection: $notchOpenMode) {
                        ForEach(NotchOpenMode.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                }
                row("서랍 닫기") {
                    Picker("서랍 닫기", selection: $closeMode) {
                        ForEach(CloseMode.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                }
            }
            Divider()
            section("관리") {
                row("메뉴막대 아이콘 잠깐 보이기") {
                    Button(statusItemShown ? "60초 동안 보임" : "보이기") {
                        model.onShowStatusItem?()
                        statusItemShown = true
                    }
                }
                row("로그인할 때 자동 실행") {
                    Toggle("로그인할 때 자동 실행", isOn: $loginEnabled)
                        .labelsHidden().toggleStyle(OrangeSwitchStyle(scale: scale))
                        .onChange(of: loginEnabled) { _, newValue in setLogin(newValue) }
                }
                if let loginMessage {
                    Text(loginMessage)
                        .font(.system(size: 11 * scale))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2 * scale)
                }
                row("TopTiroir 정보") {
                    Text("버전 \(Self.version)").font(font).foregroundStyle(.secondary)
                }
                row("TopTiroir 종료") {
                    Button("종료") { NSApp.terminate(nil) }
                        .keyboardShortcut("q", modifiers: .command)
                        .help("⌘Q")
                }
            }
        }
        .controlSize(controlSize)
        .padding(.horizontal, 6 * scale)
        .padding(.top, 4 * scale)
        .onAppear { refreshLogin() }
    }

    // MARK: 줄·구역

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10.5 * scale, weight: .bold))
                .foregroundStyle(palette.sectionTitle)
                .padding(.top, 6 * scale)
                .padding(.bottom, 2 * scale)
            content()
        }
        .padding(.bottom, 4 * scale)
    }

    private func row<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 8 * scale) {
            Text(label).font(font)
            Spacer(minLength: 8 * scale)
            control()
        }
        .frame(height: 21 * scale)
    }

    private func toggle(_ binding: Binding<Bool>) -> some View {
        Toggle("", isOn: binding).labelsHidden().toggleStyle(OrangeSwitchStyle(scale: scale))
    }

    // MARK: 값 연결

    /// 끄는 동안 서랍 크기가 바뀌면 슬라이드바가 손에서 도망가므로, 손을 뗄 때 적용한다.
    private var scaleBinding: Binding<Double> {
        Binding(get: { scaleDraft ?? drawerScale }, set: { scaleDraft = $0 })
    }

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
