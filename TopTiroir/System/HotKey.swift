import Carbon.HIToolbox

/// 전역 단축키(Carbon RegisterEventHotKey). 손쉬운 사용 권한이 필요 없다.
@MainActor
final class HotKey {
    private static var current: HotKey?

    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    /// 지금 등록된 단축키(없으면 nil)
    private(set) var registered: Shortcut?

    init(action: @escaping () -> Void) {
        self.action = action
    }

    /// 성공하면 true. 다른 앱이 같은 키를 이미 쓰고 있거나 macOS가 막으면 false(이때는 아무 키도 등록되지 않은 상태).
    @discardableResult
    func register(_ shortcut: Shortcut) -> Bool {
        unregister()
        guard installHandlerIfNeeded() else { return false }
        let id = EventHotKeyID(signature: OSType(0x5454_5452), id: 1) // 'TTTR'
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id,
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
        if handlerRef != nil { return true }
        HotKey.current = self
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            // Carbon은 메인 스레드에서 이 함수를 부른다.
            MainActor.assumeIsolated { HotKey.current?.action() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
        return status == noErr
    }
}
