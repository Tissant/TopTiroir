import Testing
@testable import TopTiroir

struct V080Tests {
    @Test func 열면_바로_닫기는_기본_꺼짐() {
        #expect(SettingsDefault.closeOnOpen == false)
        #expect(SettingsKey.closeOnOpen == "closeOnOpen")
    }
}
