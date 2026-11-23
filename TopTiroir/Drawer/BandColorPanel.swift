import AppKit

/// 색 고르기(띠 색·서랍 색). SwiftUI ColorPicker는 다른 앱을 비활성으로 만들지 않는 서랍(nonactivating panel)에서
/// 색 변경을 전달하지 못해, 시스템 색상 창에 직접 대상(target)·동작(action)을 연결한다.
/// 색상 창은 하나라서, 어느 견본이 열었는지(저장할 설정 이름)를 기억해 값이 섞이지 않게 한다.
@MainActor
final class BandColorPanel: NSObject {
    static let shared = BandColorPanel()

    /// 지금 색상 창이 바꾸는 설정 이름(SettingsKey.bandColor 또는 drawerColor)
    private(set) var editingKey: String?

    /// 서랍 오른쪽 옆, 서랍보다 한 층 위에 띄운다.
    func show(key: String, fallback: String, nextTo drawerFrame: NSRect, above level: NSWindow.Level) {
        let panel = NSColorPanel.shared
        // 색을 정확히 보도록 서랍 투명도와 상관없이 항상 불투명
        panel.alphaValue = 1
        panel.showsAlpha = false
        // 서랍은 앱을 활성으로 만들지 않는다. NSPanel 기본값(비활성 때 숨김)이면 열리자마자 숨어 버린다.
        panel.hidesOnDeactivate = false
        // 대상을 먼저 끊고 색을 바꿔야, 바뀐 색이 이전 견본 설정에 저장되지 않는다.
        panel.setTarget(nil)
        editingKey = key
        panel.color = NSColor(ttHex: UserDefaults.standard.string(forKey: key) ?? fallback)
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
        editingKey = nil
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        guard let key = editingKey, let hex = sender.color.ttHex else { return }
        UserDefaults.standard.set(hex, forKey: key)
    }
}
