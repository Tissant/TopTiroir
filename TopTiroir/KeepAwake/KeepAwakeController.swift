import AppKit
import Observation

/// 서랍 화면이 보는 화면 켜 두기 상태
@MainActor
@Observable
final class KeepAwakeModel {
    var isRunning = false
    var remainingText = ""
    /// 지금 충전 중인지(「계속」 고르기 안내용)
    var onAC = true
    /// 자동으로 꺼진 이유: 다음에 서랍을 열 때 한 번 보여 준다.
    var notice: String?
    /// 시작에 실패했을 때 설정 줄 아래 안내
    var startError: String?

    @ObservationIgnored var onStart: ((KeepAwakePlan) -> Void)?
    @ObservationIgnored var onStop: (() -> Void)?
}

/// 화면 켜 두기: 시작·1초 점검·자동 끄기·켜짐 표시. 꺼지면 타이머·전원 감시·표시 창을 모두 없앤다.
@MainActor
final class KeepAwakeController {
    let model = KeepAwakeModel()
    private let session = KeepAwakeSession(blocker: IOPMDisplaySleepBlocker())
    private let powerMonitor = PowerMonitor()
    private let overlay = IndicatorOverlay()
    private var timer: Timer?
    private var timerInterval: TimeInterval = 0
    /// 전원 상태(알림이 오거나 1초마다 새로 읽음)
    private var power: PowerState = PowerMonitor.current
    private var lastPowerRead = Date.distantPast
    private var lastSecondTick = Date.distantPast
    private var shownLook: (IndicatorStyle, String, Int)?
    /// 시작 후 서랍을 닫는 일(DrawerController가 맡음)
    var closeDrawer: (() -> Void)?

    init() {
        model.onStart = { [weak self] plan in self?.start(plan) }
        model.onStop = { [weak self] in self?.stop(reason: .stopped) }
        powerMonitor.onChange = { [weak self] in self?.powerChanged() }
        model.onAC = PowerMonitor.current.onAC
    }

    /// 서랍을 열 때: 최신 전원·남은 시간
    func refreshForDrawer() {
        model.onAC = PowerMonitor.current.onAC
        if session.isRunning { model.remainingText = KeepAwake.remainingText(end: session.end, now: Date()) }
    }

    func start(_ plan: KeepAwakePlan) {
        let p = PowerMonitor.current
        model.onAC = p.onAC
        if let error = session.begin(plan, now: Date(), power: p) {
            model.startError = error.message
            return
        }
        model.startError = nil
        model.notice = nil
        model.isRunning = true
        powerMonitor.start()   // 켜 두는 동안에만 전원 알림을 받는다
        power = p
        scheduleTimer()
        refreshIndicator(force: true)
        tick()
        closeDrawer?()
    }

    func stop(reason: KeepAwakeStopReason) {
        if session.isRunning { session.stop() }
        timer?.invalidate()
        timer = nil
        timerInterval = 0
        powerMonitor.stop()
        overlay.removeAll()
        shownLook = nil
        model.isRunning = false
        model.remainingText = ""
        if let message = reason.message { model.notice = message }
    }

    /// 표시 모양·색·화면이 바뀌면 다시 그린다(다른 설정이 바뀐 때는 그대로 둔다).
    func refreshIndicator(force: Bool = false) {
        guard session.isRunning, let start = session.start else { return }
        let d = UserDefaults.standard
        let style = IndicatorStyle.resolve(d.string(forKey: SettingsKey.indicatorStyle))
        let hex = d.string(forKey: SettingsKey.indicatorColor) ?? SettingsDefault.indicatorColor
        let look = (style, hex, NSScreen.screens.count)
        if !force, let shown = shownLook, shown == look { return }
        shownLook = look
        let color = NSColor(ttHex: hex)
        overlay.show(style: style, color: color,
                     fraction: KeepAwake.barFraction(start: start, end: session.end, now: Date()),
                     continuous: session.end == nil)
    }

    /// 「키보드·마우스를 쓰면 끄기」가 켜져 있을 때만 0.25초마다(한 번의 입력에도 바로 끄려고), 아니면 1초마다.
    private func scheduleTimer() {
        let interval = Self.autoStopSettings.onInput ? KeepAwake.inputCheckInterval : 1
        guard session.isRunning, interval != timerInterval else { return }
        timer?.invalidate()
        timerInterval = interval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { [weak self] in self?.tick() }
        }
        timer?.tolerance = interval * 0.2
        RunLoop.main.add(timer!, forMode: .common)   // 메뉴를 여는 중에도 점검
    }

    /// 설정이 바뀌면(키보드·마우스 조건 켜고 끔) 점검 간격을 맞춘다.
    func settingsChanged() {
        scheduleTimer()
        refreshIndicator()
    }

    private func tick() {
        let now = Date()
        if now.timeIntervalSince(lastPowerRead) >= 1 {
            power = PowerMonitor.current
            lastPowerRead = now
            model.onAC = power.onAC
        }
        if let reason = session.tick(now: now, power: power, secondsSinceInput: InputIdle.seconds, settings: Self.autoStopSettings) {
            stop(reason: reason)
            return
        }
        // 남은 시간 글자·막대는 1초에 한 번만
        guard let start = session.start, now.timeIntervalSince(lastSecondTick) >= 0.95 else { return }
        lastSecondTick = now
        model.remainingText = KeepAwake.remainingText(end: session.end, now: now)
        overlay.update(fraction: KeepAwake.barFraction(start: start, end: session.end, now: now))
    }

    private func powerChanged() {
        guard session.isRunning else { return }
        power = PowerMonitor.current   // 충전기 빠짐 등은 기다리지 않고 바로 판단
        lastPowerRead = Date()
        model.onAC = power.onAC
        tick()
    }

    static var autoStopSettings: AutoStopSettings {
        let d = UserDefaults.standard
        return AutoStopSettings(onInput: d.bool(forKey: SettingsKey.autoStopOnInput),
                                onBattery: d.bool(forKey: SettingsKey.autoStopOnBattery),
                                onLowBattery: d.bool(forKey: SettingsKey.autoStopOnLowBattery),
                                lowBatteryPercent: d.integer(forKey: SettingsKey.autoStopLowBatteryPercent))
    }
}
