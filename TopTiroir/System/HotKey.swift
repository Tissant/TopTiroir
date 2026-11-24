import Carbon.HIToolbox

/// 전역 단축키(Carbon RegisterEventHotKey). 손쉬운 사용 권한이 필요 없다.
@MainActor
final class HotKey {
    /// 등록된 전역 단축키들(번호 → 객체). 눌림 이벤트는 번호로 찾아 보낸다.
    private static var registry: [UInt32: HotKey] = [:]
    private static var handlerRef: EventHandlerRef?

    private let id: UInt32
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    /// 지금 등록된 단축키(없으면 nil)
    private(set) var registered: Shortcut?

    init(id: UInt32 = 1, action: @escaping () -> Void) {
        self.id = id
        self.action = action
        HotKey.registry[id] = self
    }

    /// 성공하면 true. 다른 앱이 같은 키를 이미 쓰고 있거나 macOS가 막으면 false(이때는 아무 키도 등록되지 않은 상태).
    @discardableResult
    func register(_ shortcut: Shortcut) -> Bool {
        unregister()
        guard installHandlerIfNeeded() else { return false }
        let hotKeyID = EventHotKeyID(signature: OSType(0x5454_5452), id: id) // 'TTTR'
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else {
            hotKeyRef = nil
            return false
        }
        registered = shortcut
        return true
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        hotKeyRef = nil
        registered = nil
    }

    private func installHandlerIfNeeded() -> Bool {
        if HotKey.handlerRef != nil { return true }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let got = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                        nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard got == noErr else { return noErr }
            // Carbon은 메인 스레드에서 이 함수를 부른다.
            MainActor.assumeIsolated { HotKey.registry[hotKeyID.id]?.action() }
            return noErr
        }, 1, &spec, nil, &HotKey.handlerRef)
        return status == noErr
    }
}
