import Foundation

/// 설치판과 개발판(Debug 빌드)을 구분한다. 개발판은 번들 ID가 `.dev`로 끝난다(local.toptiroir.app.dev).
/// 개발판은 설정(UserDefaults)·손쉬운 사용 권한·저장 폴더가 설치판과 따로라서, 시험하다가 실제 메모를 건드리지 않는다.
enum AppIdentity {
    static let devSuffix = ".dev"

    static func isDev(bundleID: String?) -> Bool {
        bundleID?.hasSuffix(devSuffix) ?? false
    }

    /// ~/Library/Application Support 아래 저장 폴더 이름
    static func supportFolderName(bundleID: String?) -> String {
        isDev(bundleID: bundleID) ? "TopTiroir-Dev" : "TopTiroir"
    }

    /// 지금 실행 중인 앱이 개발판인지
    static var isDevBuild: Bool { isDev(bundleID: Bundle.main.bundleIdentifier) }
}
