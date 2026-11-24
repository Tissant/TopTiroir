import CoreGraphics
import Foundation
import IOKit.ps
import IOKit.pwr_mgt

/// 화면이 저절로 꺼지지 않게 하는 macOS 어서션(IOPMAssertion). 권한이 필요 없다.
final class IOPMDisplaySleepBlocker: DisplaySleepBlocking {
    private var id: IOPMAssertionID = 0
    private var held = false

    func begin(reason: String) -> Bool {
        if held { end() }
        let status = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                                 IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                 reason as CFString, &id)
        held = status == kIOReturnSuccess
        return held
    }

    func end() {
        guard held else { return }
        IOPMAssertionRelease(id)
        held = false
        id = 0
    }

    deinit { end() }
}

/// 전원 상태(충전기·배터리 %)와 바뀜 알림
@MainActor
final class PowerMonitor {
    private var source: CFRunLoopSource?
    var onChange: (() -> Void)?

    static var current: PowerState {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return PowerState(onAC: true, batteryPercent: nil) }
        let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        let onAC = type != kIOPSBatteryPowerValue
        var percent: Int?
        if let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for ps in list {
                guard let d = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
                      let cur = d[kIOPSCurrentCapacityKey] as? Int, let max = d[kIOPSMaxCapacityKey] as? Int, max > 0
                else { continue }
                percent = Int((Double(cur) / Double(max) * 100).rounded())
            }
        }
        return PowerState(onAC: onAC, batteryPercent: percent)
    }

    func start() {
        guard source == nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let s = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.onChange?() }
        }, context)?.takeRetainedValue() else { return }
        source = s
        CFRunLoopAddSource(CFRunLoopGetMain(), s, .defaultMode)
    }

    func stop() {
        if let s = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .defaultMode) }
        source = nil
    }
}

/// 마지막 키보드·마우스 입력 뒤 지난 초. 입력 내용은 보지 않으며 권한이 필요 없다.
/// 「아무 입력」과 마우스 이동·클릭·스크롤·키·수정키 각각의 경과 시간 중 가장 짧은 값.
enum InputIdle {
    private static let types: [CGEventType] = [
        CGEventType(rawValue: ~0)!, .mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown,
        .leftMouseDragged, .scrollWheel, .keyDown, .flagsChanged,
    ]

    static var seconds: TimeInterval {
        types.map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }.min() ?? .infinity
    }
}
