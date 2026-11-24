import Foundation
import ServiceManagement
import os

private let loginLog = Logger(subsystem: "local.toptiroir.app", category: "LoginItem")

/// 로그인할 때 자동 실행 (시스템 설정 → 일반 → 로그인 항목에 나타난다)
@MainActor
enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static var isEnabled: Bool { status == .enabled }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(Bundle.main.bundlePath, forKey: SettingsKey.loginItemPath)
        } else {
            try SMAppService.mainApp.unregister()
            UserDefaults.standard.removeObject(forKey: SettingsKey.loginItemPath)
        }
    }

    /// 앱을 시작할 때: 자동 실행이 켜져 있는데 다른 위치(예: 개발용 build 폴더)로 등록돼 있으면
    /// 지금 앱(/Applications)으로 다시 등록한다. 개발용 빌드에서는 아무것도 하지 않는다.
    static func reregisterIfMoved() {
        let current = Bundle.main.bundlePath
        let saved = UserDefaults.standard.string(forKey: SettingsKey.loginItemPath)
        guard LoginItemPolicy.shouldReregister(enabled: isEnabled, registeredPath: saved, currentPath: current) else { return }
        do {
            try? SMAppService.mainApp.unregister()
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(current, forKey: SettingsKey.loginItemPath)
            loginLog.notice("자동 실행을 설치된 앱 위치로 다시 등록함")
        } catch {
            loginLog.error("자동 실행 다시 등록 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
}
