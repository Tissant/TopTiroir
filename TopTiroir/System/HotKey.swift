import Carbon.HIToolbox

/// 전역 단축키(Carbon RegisterEventHotKey). 손쉬운 사용 권한이 필요 없다.
@MainActor
final class HotKey {
    private static var current: HotKey?

    private let keyCode: UInt32
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(keyCode: UInt32, action: @escaping () -> Void) {
        self.keyCode = keyCode
        self.action = action
    }

    /// 성공하면 true. 다른 앱이 같은 키를 이미 쓰고 있으면 false.
    @discardableResult
    func register() -> Bool {
        HotKey.current = self
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            // Carbon은 메인 스레드에서 이 함수를 부른다.
            MainActor.assumeIsolated { HotKey.current?.action() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
        guard installStatus == noErr else { return false }

        let id = EventHotKeyID(signature: OSType(0x5454_5452), id: 1) // 'TTTR'
        let status = RegisterEventHotKey(keyCode, 0, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        return status == noErr
    }

    static let f12 = UInt32(kVK_F12)
}
