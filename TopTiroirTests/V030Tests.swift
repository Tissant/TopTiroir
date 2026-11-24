import CoreGraphics
import Foundation
import Testing

/// v0.3.0: 화면 켜 두기(끝나는 시각·남은 시간·막대·자동 끄기·세션)와 켜짐 표시 위치
struct KeepAwakeTimeTests {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    func date(_ h: Int, _ m: Int, day: Int = 24) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: h, minute: m))!
    }

    @Test func durationEnd() {
        let now = date(10, 0)
        let r = KeepAwake.endDate(for: KeepAwakePlan(mode: .duration, durationMinutes: 90), now: now, onAC: false, calendar: cal)
        #expect(r == .success(date(11, 30)))
        // 목록에 없는 값은 기본 30분
        let odd = KeepAwake.endDate(for: KeepAwakePlan(mode: .duration, durationMinutes: 7), now: now, onAC: false, calendar: cal)
        #expect(odd == .success(date(10, 30)))
    }

    @Test func continuousNeedsPower() {
        #expect(KeepAwake.endDate(for: KeepAwakePlan(mode: .continuous), now: date(10, 0), onAC: true, calendar: cal) == .success(nil))
        #expect(KeepAwake.endDate(for: KeepAwakePlan(mode: .continuous), now: date(10, 0), onAC: false, calendar: cal) == .failure(.needsPower))
    }

    @Test func untilTimeAcrossMidnight() {
        let plan = KeepAwakePlan(mode: .until, untilMinuteOfDay: 2 * 60)        // 02:00
        let r = KeepAwake.endDate(for: plan, now: date(23, 30), onAC: false, calendar: cal)
        #expect(r == .success(date(2, 0, day: 25)))
    }

    @Test func untilTimeLimits() {
        let now = date(10, 0)
        #expect(KeepAwake.endDate(for: KeepAwakePlan(mode: .until, untilMinuteOfDay: 15 * 60), now: now, onAC: false, calendar: cal)
                == .success(date(15, 0)))                                          // 정확히 5시간
        #expect(KeepAwake.endDate(for: KeepAwakePlan(mode: .until, untilMinuteOfDay: 15 * 60 + 1), now: now, onAC: false, calendar: cal)
                == .failure(.tooFar))
        #expect(KeepAwake.endDate(for: KeepAwakePlan(mode: .until, untilMinuteOfDay: 9 * 60), now: now, onAC: false, calendar: cal)
                == .failure(.alreadyPassed))
        #expect(KeepAwake.endDate(for: KeepAwakePlan(mode: .until, untilMinuteOfDay: 10 * 60), now: now, onAC: false, calendar: cal)
                == .failure(.alreadyPassed))                                       // 지금과 같은 시각
    }

    @Test func remainingTexts() {
        let now = date(10, 0)
        #expect(KeepAwake.remainingText(end: nil, now: now) == "계속")
        #expect(KeepAwake.remainingText(end: now.addingTimeInterval(84 * 60), now: now) == "1:24 남음")
        #expect(KeepAwake.remainingText(end: now.addingTimeInterval(23 * 60 + 10), now: now) == "24분 남음")
        #expect(KeepAwake.remainingText(end: now.addingTimeInterval(30), now: now) == "1분 미만 남음")
        #expect(KeepAwake.durationTitle(90) == "1시간 30분")
        #expect(KeepAwake.durationTitle(45) == "45분")
        #expect(KeepAwake.durationTitle(300) == "5시간")
    }

    @Test func barFraction() {
        let start = date(10, 0), end = date(11, 0)
        #expect(KeepAwake.barFraction(start: start, end: end, now: start) == 1)
        #expect(KeepAwake.barFraction(start: start, end: end, now: date(10, 45)) == 0.25)
        #expect(KeepAwake.barFraction(start: start, end: end, now: date(12, 0)) == 0)
        #expect(KeepAwake.barFraction(start: start, end: nil, now: date(12, 0)) == 1)
    }
}

struct AutoStopTests {
    let start = Date(timeIntervalSince1970: 1_000_000)
    let ac = PowerState(onAC: true, batteryPercent: 80)
    let battery = PowerState(onAC: false, batteryPercent: 60)

    func reason(_ mode: KeepAwakeMode = .duration, end: Date? = nil, at sec: TimeInterval, power: PowerState,
                idle: TimeInterval = 999, _ s: AutoStopSettings = AutoStopSettings()) -> KeepAwakeStopReason? {
        KeepAwake.stopReason(mode: mode, end: end, start: start, now: start.addingTimeInterval(sec), power: power,
                             secondsSinceInput: idle, settings: s)
    }

    @Test func defaults() {
        let d = AutoStopSettings()
        #expect(!d.onInput && d.onBattery && d.onLowBattery && d.lowBatteryPercent == 20)
    }

    @Test func timeUp() {
        #expect(reason(end: start.addingTimeInterval(60), at: 60, power: ac) == .timeUp)
        #expect(reason(end: start.addingTimeInterval(60), at: 59, power: ac) == nil)
    }

    @Test func inputWithGrace() {
        var s = AutoStopSettings(); s.onInput = true
        #expect(reason(at: 1.5, power: ac, idle: 0, s) == nil)      // 유예(2초) 중 입력은 무시
        #expect(reason(at: 20, power: ac, idle: 18.5, s) == nil)    // 마지막 입력이 1.5초째(유예 안)
        #expect(reason(at: 20, power: ac, idle: 999, s) == nil)     // 입력 없음
        s.onInput = false
        #expect(reason(at: 20, power: ac, idle: 0.1, s) == nil)
    }

    @Test func singleInputStopsRightAfterGrace() {
        var s = AutoStopSettings(); s.onInput = true
        // 유예가 끝난 뒤 딱 한 번 입력(0.1초 전) → 바로 꺼짐
        #expect(reason(at: 2.3, power: ac, idle: 0.1, s) == .input)
        #expect(reason(at: 60, power: ac, idle: 0.2, s) == .input)
        #expect(KeepAwake.inputDetected(secondsSinceInput: 0.2, now: start.addingTimeInterval(10), start: start))
        #expect(!KeepAwake.inputDetected(secondsSinceInput: 9, now: start.addingTimeInterval(10), start: start))
    }

    @Test func batteryRules() {
        #expect(reason(at: 10, power: battery) == .onBattery)
        var s = AutoStopSettings(); s.onBattery = false
        #expect(reason(at: 10, power: battery, s) == nil)                                  // 60% > 20%
        #expect(reason(at: 10, power: PowerState(onAC: false, batteryPercent: 20), s) == .lowBattery(20))
        s.lowBatteryPercent = 70
        #expect(reason(at: 10, power: PowerState(onAC: false, batteryPercent: 45), s) == .lowBattery(50)) // 70% → 최대 50%로 맞춤
        s.onLowBattery = false
        #expect(reason(at: 10, power: PowerState(onAC: false, batteryPercent: 3), s) == nil)
        #expect(reason(at: 10, power: PowerState(onAC: true, batteryPercent: 3)) == nil)   // 충전 중엔 무시
    }

    @Test func continuousStopsWhenUnplugged() {
        var s = AutoStopSettings(); s.onBattery = false; s.onLowBattery = false
        #expect(reason(.continuous, at: 10, power: battery, s) == .continuousUnplugged)
        #expect(reason(.continuous, at: 10, power: ac, s) == nil)
    }
}

final class FakeBlocker: DisplaySleepBlocking {
    var active = 0, begins = 0, ends = 0
    var allow = true
    func begin(reason: String) -> Bool {
        guard allow else { return false }
        begins += 1; active += 1
        #expect(reason == "TopTiroir 화면 켜 두기")
        return true
    }
    func end() { ends += 1; active -= 1 }
}

struct KeepAwakeSessionTests {
    let now = Date(timeIntervalSince1970: 2_000_000)
    let ac = PowerState(onAC: true, batteryPercent: 90)

    @Test func startTickStop() {
        let fake = FakeBlocker()
        let session = KeepAwakeSession(blocker: fake)
        #expect(session.begin(KeepAwakePlan(mode: .duration, durationMinutes: 5), now: now, power: ac) == nil)
        #expect(fake.active == 1 && session.isRunning)
        #expect(session.tick(now: now.addingTimeInterval(60), power: ac, secondsSinceInput: 999, settings: .init()) == nil)
        #expect(session.tick(now: now.addingTimeInterval(300), power: ac, secondsSinceInput: 999, settings: .init()) == .timeUp)
        #expect(fake.active == 0 && fake.ends == 1 && !session.isRunning)
        session.stop()                                   // 두 번 풀지 않음
        #expect(fake.ends == 1)
    }

    @Test func restartReleasesOldOne() {
        let fake = FakeBlocker()
        let session = KeepAwakeSession(blocker: fake)
        _ = session.begin(KeepAwakePlan(mode: .continuous), now: now, power: ac)
        _ = session.begin(KeepAwakePlan(mode: .duration, durationMinutes: 10), now: now, power: ac)
        #expect(fake.active == 1 && fake.begins == 2 && fake.ends == 1)
    }

    @Test func failuresDoNotHoldAssertion() {
        let fake = FakeBlocker()
        let session = KeepAwakeSession(blocker: fake)
        #expect(session.begin(KeepAwakePlan(mode: .continuous), now: now, power: PowerState(onAC: false, batteryPercent: 50))
                == .needsPower)
        fake.allow = false
        #expect(session.begin(KeepAwakePlan(mode: .duration), now: now, power: ac) == .unavailable)
        #expect(fake.active == 0 && !session.isRunning)
    }
}

struct IndicatorLayoutTests {
    let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)

    @Test func barBelowMenuBar() {
        // 선 2 + 빛 자리 10, 메뉴막대(37) 바로 아래부터
        #expect(Layout.indicatorBarRect(screenFrame: screen, menuBarHeight: 37) == CGRect(x: 0, y: 1063, width: 1710, height: 12))
        #expect(Layout.indicatorHaloRect(screenFrame: screen, menuBarHeight: 37) == CGRect(x: 0, y: 1059, width: 1710, height: 16))
    }

    @Test func oldNotchGlowBecomesBar() {
        #expect(IndicatorStyle.resolve("notchGlow") == .bar)
        #expect(IndicatorStyle.resolve(nil) == .bar)
        #expect(IndicatorStyle.resolve("breathe") == .breathe)
        #expect(IndicatorStyle.allCases.count == 7)
        #expect(IndicatorStyle.resolve("aurora") == .aurora)
        #expect(IndicatorStyle.resolve("엉뚱한값") == .bar)
    }

    @Test func highlightColor() {
        let c = HexColor.lightened(RGB(red: 1, green: 0.5, blue: 0), by: 0.5)
        #expect(c == RGB(red: 1, green: 0.75, blue: 0.5))
        #expect(HexColor.lightened(RGB(red: 0.2, green: 0.2, blue: 0.2), by: 0) == RGB(red: 0.2, green: 0.2, blue: 0.2))
    }
}


struct NewIndicatorTests {
    @Test func dotClockOpacities() {
        let full = KeepAwake.dotOpacities(fraction: 1)
        #expect(full.count == 10 && full.allSatisfy { $0 == 1 })
        let half = KeepAwake.dotOpacities(fraction: 0.55)    // 5.5개: 왼쪽 5개 켜짐, 6번째 반쯤, 나머지 옅게
        #expect(half[0...4].allSatisfy { $0 == 1 })
        #expect(abs(half[5] - (0.15 + 0.85 * 0.5)) < 0.0001)
        #expect(half[6...].allSatisfy { $0 == 0.15 })
        #expect(KeepAwake.dotOpacities(fraction: 0).allSatisfy { $0 == 0.15 })
    }

    @Test func auroraColorsAroundBase() {
        let base = RGB(red: 1, green: 0, blue: 0)
        let c = KeepAwake.auroraColors(base)
        #expect(c.count == 3 && c[1] == base)
        #expect(c[0] != base && c[2] != base)
    }

    @Test func remainingStyles() {
        #expect(IndicatorStyle.bar.showsRemaining && IndicatorStyle.lightStream.showsRemaining && IndicatorStyle.dotClock.showsRemaining)
        #expect(!IndicatorStyle.softHalo.showsRemaining && !IndicatorStyle.notchHalo.showsRemaining)
    }

    @Test func savedStyleRoundTrip() {
        for style in IndicatorStyle.allCases { #expect(IndicatorStyle.resolve(style.rawValue) == style) }
        #expect(IndicatorStyle.resolve("hourglass") == .bar)   // 모르는 값
    }

    @Test func hueShift() {
        let green = HexColor.hueShifted(RGB(red: 1, green: 0, blue: 0), by: 120)
        #expect(abs(green.red) < 0.001 && abs(green.green - 1) < 0.001 && abs(green.blue) < 0.001)
        let back = HexColor.hueShifted(RGB(red: 1, green: 0, blue: 0), by: -120)
        #expect(abs(back.blue - 1) < 0.001)
        let gray = HexColor.hueShifted(RGB(red: 0.5, green: 0.5, blue: 0.5), by: 90)
        #expect(gray == RGB(red: 0.5, green: 0.5, blue: 0.5))
    }

    @Test func overlayRects() {
        let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)
        let notch = CGRect(x: 762, y: 1075, width: 185, height: 37)
        let d = Layout.dotClockRect(screenFrame: screen, menuBarHeight: 37, centerX: notch.midX)
        #expect(abs(d.midX - notch.midX) < 0.001 && d.maxY == 1075)
        let h = Layout.notchHaloRect(screenFrame: screen, menuBarHeight: 37, notch: notch)
        #expect(h == CGRect(x: 740, y: 1053, width: 229, height: 59))
        let ext = CGRect(x: 1710, y: 0, width: 1920, height: 1080)
        #expect(abs(Layout.notchHaloRect(screenFrame: ext, menuBarHeight: 24, notch: nil).midX - ext.midX) < 0.001)
    }
}
