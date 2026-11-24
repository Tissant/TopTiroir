import Testing

/// 1.0.0: 개발판(Debug)과 설치판 구분
struct AppIdentityTests {
    @Test func 개발판은_번들_ID_끝이_dev() {
        #expect(AppIdentity.isDev(bundleID: "local.toptiroir.app.dev"))
        #expect(!AppIdentity.isDev(bundleID: "local.toptiroir.app"))
        #expect(!AppIdentity.isDev(bundleID: nil))
    }

    @Test func 개발판은_저장_폴더가_따로() {
        #expect(AppIdentity.supportFolderName(bundleID: "local.toptiroir.app") == "TopTiroir")
        #expect(AppIdentity.supportFolderName(bundleID: "local.toptiroir.app.dev") == "TopTiroir-Dev")
        #expect(AppIdentity.supportFolderName(bundleID: nil) == "TopTiroir")
    }

    @Test func 예전에_메뉴막대_탭을_마지막으로_봤어도_메모_탭으로() {
        #expect(OpenTabMode.last.tab(lastTab: "menuBar") == .notes)
    }
}
