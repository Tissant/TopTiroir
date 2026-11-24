import Foundation

/// 화면 켜 두기: 방식·끝나는 시각·남은 시간·자동 끄기 판단. AppKit·IOKit 없이 숫자만 다룬다.

enum KeepAwakeMode: String, CaseIterable, Sendable {
    case continuous, duration, until
    var title: String {
        switch self {
        case .continuous: "계속"
        case .duration: "일정 시간"
        case .until: "시각까지"
        }
    }
}

/// 시작할 때 고른 내용
struct KeepAwakePlan: Equatable, Sendable {
    var mode: KeepAwakeMode
    var durationMinutes: Int = KeepAwake.defaultDuration
    /// 시각까지: 하루 중 몇 분째(예: 14:30 → 870)
    var untilMinuteOfDay: Int = 0
}

enum KeepAwakeStartError: Error, Equatable, Sendable {
    case needsPower       // 계속: 충전 중에만
    case alreadyPassed    // 시각까지: 이미 지난 시각
    case tooFar           // 시각까지: 5시간보다 먼 시각
    case unavailable      // macOS가 켜 두기를 거부

    var message: String {
        switch self {
        case .needsPower: "「계속」은 충전 중에만 쓸 수 있어요."
        case .alreadyPassed: "이미 지난 시각이에요. 5시간 안의 시각을 골라 주세요."
        case .tooFar: "지금부터 5시간 안의 시각만 고를 수 있어요."
        case .unavailable: "화면 켜 두기를 시작하지 못했어요."
        }
    }
}

/// 자동으로 꺼진 이유(다음에 서랍을 열 때 한 번 보여 줌)
enum KeepAwakeStopReason: Equatable, Sendable {
    case timeUp, input, onBattery, lowBattery(Int), continuousUnplugged, stopped

    var message: String? {
        switch self {
        case .timeUp: "정한 시간이 끝나 화면 켜 두기를 껐어요."
        case .input: "키보드·마우스 사용으로 화면 켜 두기를 껐어요."
        case .onBattery: "배터리로 바뀌어 화면 켜 두기를 껐어요."
        case .lowBattery(let p): "배터리가 \(p)% 이하라 화면 켜 두기를 껐어요."
        case .continuousUnplugged: "충전기가 빠져 「계속」 화면 켜 두기를 껐어요."
        case .stopped: nil   // 직접 중지: 안내 없음
        }
    }
}

struct PowerState: Equatable, Sendable {
    var onAC: Bool
    /// 배터리 % (배터리가 없는 맥이면 nil)
    var batteryPercent: Int?
}

struct AutoStopSettings: Equatable, Sendable {
    var onInput = false
    var onBattery = true
    var onLowBattery = true
    var lowBatteryPercent = 20
}

enum KeepAwake {
    static let maxSeconds: TimeInterval = 5 * 60 * 60
    static let durations = [5, 10, 15, 30, 45, 60, 90, 120, 180, 240, 300]
    static let defaultDuration = 30
    static let lowBatteryRange: ClosedRange<Int> = 5...50
    /// 시작 직후 「시작」 클릭·서랍 닫힘을 「사용」으로 보지 않는 시간
    static let inputGraceSeconds: TimeInterval = 2
    /// 키보드·마우스 끄기를 켰을 때 점검 간격(이 조건이 꺼져 있으면 1초)
    static let inputCheckInterval: TimeInterval = 0.25

    /// 마지막 입력이 「시작 + 유예」보다 뒤면 사용한 것(입력 한 번이면 충분)
    static func inputDetected(secondsSinceInput: TimeInterval, now: Date, start: Date) -> Bool {
        now.addingTimeInterval(-secondsSinceInput) > start.addingTimeInterval(inputGraceSeconds)
    }
    static let assertionReason = "TopTiroir 화면 켜 두기"

    static func clampedDuration(_ minutes: Int) -> Int {
        durations.contains(minutes) ? minutes : defaultDuration
    }

    static func clampedLowBattery(_ p: Int) -> Int {
        min(max(p, lowBatteryRange.lowerBound), lowBatteryRange.upperBound)
    }

    /// 「1시간 30분」 「45분」
    static func durationTitle(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m)분"
        case (_, 0): return "\(h)시간"
        default: return "\(h)시간 \(m)분"
        }
    }

    /// 끝나는 시각. 계속이면 nil.
    static func endDate(for plan: KeepAwakePlan, now: Date, onAC: Bool,
                        calendar: Calendar = .current) -> Result<Date?, KeepAwakeStartError> {
        switch plan.mode {
        case .continuous:
            return onAC ? .success(nil) : .failure(.needsPower)
        case .duration:
            return .success(now.addingTimeInterval(TimeInterval(clampedDuration(plan.durationMinutes) * 60)))
        case .until:
            let minuteOfDay = ((plan.untilMinuteOfDay % 1440) + 1440) % 1440
            let startOfDay = calendar.startOfDay(for: now)
            guard var target = calendar.date(byAdding: .minute, value: minuteOfDay, to: startOfDay) else {
                return .failure(.alreadyPassed)
            }
            var passedToday = false
            if target <= now {   // 오늘 이미 지남 → 내일 그 시각(자정 넘김)
                passedToday = true
                target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
            }
            if target.timeIntervalSince(now) > maxSeconds {
                return .failure(passedToday ? .alreadyPassed : .tooFar)
            }
            return .success(target)
        }
    }

    /// 「1:24 남음」 「24분 남음」 「1분 미만 남음」, 계속이면 「계속」
    static func remainingText(end: Date?, now: Date) -> String {
        guard let end else { return "계속" }
        let seconds = max(end.timeIntervalSince(now), 0)
        let minutes = Int((seconds / 60).rounded(.up))
        if seconds < 60 { return "1분 미만 남음" }
        if minutes >= 60 { return String(format: "%d:%02d 남음", minutes / 60, minutes % 60) }
        return "\(minutes)분 남음"
    }

    /// 막대 길이 비율(1 = 꽉 참). 계속이면 1.
    static func barFraction(start: Date, end: Date?, now: Date) -> Double {
        guard let end else { return 1 }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return min(max(end.timeIntervalSince(now) / total, 0), 1)
    }

    /// 1초마다 부른다. 꺼야 하면 이유.
    static func stopReason(mode: KeepAwakeMode, end: Date?, start: Date, now: Date,
                           power: PowerState, secondsSinceInput: TimeInterval,
                           settings: AutoStopSettings) -> KeepAwakeStopReason? {
        if let end, now >= end { return .timeUp }
        if mode == .continuous && !power.onAC { return .continuousUnplugged }
        if settings.onBattery && !power.onAC { return .onBattery }
        if settings.onLowBattery, !power.onAC, let p = power.batteryPercent,
           p <= clampedLowBattery(settings.lowBatteryPercent) {
            return .lowBattery(clampedLowBattery(settings.lowBatteryPercent))
        }
        if settings.onInput && inputDetected(secondsSinceInput: secondsSinceInput, now: now, start: start) {
            return .input
        }
        return nil
    }
}

// MARK: 켜 두기 세션 (IOPMAssertion은 프로토콜로 감싸 가짜로 테스트)

protocol DisplaySleepBlocking: AnyObject {
    /// 성공하면 true
    func begin(reason: String) -> Bool
    func end()
}

/// 시작·1초 점검·중지. 켜 두기(어서션)를 꼭 한 번만 만들고 한 번만 푼다.
final class KeepAwakeSession {
    private let blocker: DisplaySleepBlocking
    private(set) var plan: KeepAwakePlan?
    private(set) var start: Date?
    private(set) var end: Date?

    var isRunning: Bool { plan != nil }

    init(blocker: DisplaySleepBlocking) { self.blocker = blocker }

    /// 시작. 문제가 있으면 그 이유, 성공하면 nil.
    func begin(_ plan: KeepAwakePlan, now: Date, power: PowerState,
               calendar: Calendar = .current) -> KeepAwakeStartError? {
        switch KeepAwake.endDate(for: plan, now: now, onAC: power.onAC, calendar: calendar) {
        case .failure(let e): return e
        case .success(let endDate):
            if isRunning { stop() }
            guard blocker.begin(reason: KeepAwake.assertionReason) else { return .unavailable }
            self.plan = plan
            start = now
            end = endDate
            return nil
        }
    }

    /// 꺼야 하면 끄고 이유를 돌려준다.
    func tick(now: Date, power: PowerState, secondsSinceInput: TimeInterval, settings: AutoStopSettings) -> KeepAwakeStopReason? {
        guard let plan, let start else { return nil }
        guard let reason = KeepAwake.stopReason(mode: plan.mode, end: end, start: start, now: now, power: power,
                                                secondsSinceInput: secondsSinceInput, settings: settings) else { return nil }
        stop()
        return reason
    }

    func stop() {
        guard isRunning else { return }
        blocker.end()
        plan = nil
        start = nil
        end = nil
    }
}

/// 켜짐 표시 모양
enum IndicatorStyle: String, CaseIterable, Sendable {
    case bar, breathe, softHalo, lightStream, aurora, dotClock, notchHalo
    var title: String {
        switch self {
        case .bar: "남은 시간 막대"
        case .breathe: "숨 쉬는 네온 테두리"
        case .softHalo: "소프트 후광"
        case .lightStream: "빛줄기 흐름"
        case .aurora: "오로라 테두리"
        case .dotClock: "점 시계"
        case .notchHalo: "노치 후광"
        }
    }
    /// 선택 상자에서 모양을 구분하는 기호
    var symbol: String {
        switch self {
        case .bar: "minus"
        case .breathe: "light.max"
        case .softHalo: "circle.dotted"
        case .lightStream: "arrow.right.to.line"
        case .aurora: "rainbow"
        case .dotClock: "ellipsis"
        case .notchHalo: "rectangle.topthird.inset.filled"
        }
    }
    /// 남은 시간을 길이·개수로 보여 주는지(1초마다 갱신이 필요한지)
    var showsRemaining: Bool { self == .bar || self == .lightStream || self == .dotClock }

    /// 저장값 → 모양. 없어진 「노치 손잡이 불빛」(notchGlow)이나 모르는 값은 막대로.
    static func resolve(_ raw: String?) -> IndicatorStyle {
        raw.flatMap(IndicatorStyle.init(rawValue:)) ?? .bar
    }
}

extension KeepAwake {
    /// 점 시계 점 개수
    static let clockDots = 10
    /// 꺼진 점도 아주 옅게 남긴다
    static let dimDotOpacity = 0.15

    /// 점마다 밝기(왼쪽→오른쪽). 남은 비율만큼 왼쪽부터 켜지고, 경계의 점은 남은 만큼만 밝다(오른쪽부터 부드럽게 꺼짐).
    static func dotOpacities(fraction: Double, total: Int = clockDots) -> [Double] {
        let f = min(max(fraction, 0), 1) * Double(total)
        return (0..<total).map { i in
            let lit = min(max(f - Double(i), 0), 1)        // 이 점이 켜진 정도 0~1
            return dimDotOpacity + (1 - dimDotOpacity) * lit
        }
    }

    /// 오로라: 선택한 색을 가운데로 색상환에서 양쪽으로 조금씩 돌린 세 가지 색
    static func auroraColors(_ base: RGB) -> [RGB] {
        [HexColor.hueShifted(base, by: -28), base, HexColor.hueShifted(base, by: 28)]
    }
}

extension Layout {
    /// 막대 선 두께와 선 아래로 퍼지는 빛 자리
    static let indicatorLineHeight: CGFloat = 2
    static let indicatorGlowSpace: CGFloat = 10
    /// 후광 높이(메뉴막대 아래로 번지는 만큼)
    static let indicatorHaloHeight: CGFloat = 16

    /// 남은 시간 막대 창: 메뉴막대(노치 띠 포함) 바로 아래부터, 선 + 빛 자리
    static func indicatorBarRect(screenFrame: CGRect, menuBarHeight: CGFloat) -> CGRect {
        let h = indicatorLineHeight + indicatorGlowSpace
        return CGRect(x: screenFrame.minX, y: screenFrame.maxY - max(menuBarHeight, 0) - h,
                      width: screenFrame.width, height: h)
    }

    /// 점 시계 창: 메뉴막대 바로 아래, 노치(없으면 화면 가운데) 밑 가운데
    static let clockDotSize: CGFloat = 4
    static let clockDotGap: CGFloat = 8
    static func dotClockRect(screenFrame: CGRect, menuBarHeight: CGFloat, centerX: CGFloat?) -> CGRect {
        let n = CGFloat(KeepAwake.clockDots)
        let width = n * clockDotSize + (n - 1) * clockDotGap + 16   // 양쪽 빛 자리 8씩
        let h: CGFloat = 14
        let mid = centerX ?? screenFrame.midX
        return CGRect(x: mid - width / 2, y: screenFrame.maxY - max(menuBarHeight, 0) - h, width: width, height: h)
    }

    /// 노치 후광 창: 노치(없으면 메뉴막대 가운데 200pt) 둘레 + 아래로 번질 자리
    static func notchHaloRect(screenFrame: CGRect, menuBarHeight: CGFloat, notch: CGRect?) -> CGRect {
        let mb = max(menuBarHeight, 0)
        let core = notch ?? CGRect(x: screenFrame.midX - 100, y: screenFrame.maxY - mb, width: 200, height: mb)
        let spread: CGFloat = 22
        return CGRect(x: core.minX - spread, y: screenFrame.maxY - mb - spread,
                      width: core.width + spread * 2, height: mb + spread)
    }

    /// 후광 창: 메뉴막대 아래 가장자리에서 아래로
    static func indicatorHaloRect(screenFrame: CGRect, menuBarHeight: CGFloat) -> CGRect {
        CGRect(x: screenFrame.minX, y: screenFrame.maxY - max(menuBarHeight, 0) - indicatorHaloHeight,
               width: screenFrame.width, height: indicatorHaloHeight)
    }
}
