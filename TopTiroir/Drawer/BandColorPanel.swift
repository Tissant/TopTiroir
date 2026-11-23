import AppKit

/// 띠 색 고르기. SwiftUI ColorPicker는 다른 앱을 비활성으로 만들지 않는 서랍(nonactivating panel)에서
/// 색 변경을 전달하지 못해, 시스템 색상 패널에 직접 대상(target)·동작(action)을 연결한다.
@MainActor
final class BandColorPanel: NSObject {
    static let shared = BandColorPanel()

    /// 서랍 오른쪽 옆, 서랍보다 한 층 위에 띄운다.
    func show(nextTo drawerFrame: NSRect, above level: NSWindow.Level) {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        // 서랍은 앱을 활성으로 만들지 않는다. NSPanel 기본값(비활성 때 숨김)이면 열리자마자 숨어 버린다.
        panel.hidesOnDeactivate = false
        panel.setTarget(nil)
        panel.color = NSColor(ttHex: UserDefaults.standard.string(forKey: SettingsKey.bandColor)
            ?? SettingsDefault.bandColor)
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.level = NSWindow.Level(rawValue: level.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setFrameTopLeftPoint(NSPoint(x: drawerFrame.maxX + 8, y: drawerFrame.maxY))
        panel.orderFrontRegardless()
    }

    func close() {
        let panel = NSColorPanel.shared
        if panel.isVisible { panel.orderOut(nil) }
        panel.setTarget(nil)
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        guard let hex = sender.color.ttHex else { return }
        UserDefaults.standard.set(hex, forKey: SettingsKey.bandColor)
    }
}
