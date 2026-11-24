import AppKit

/// 메뉴막대 아이콘을 잠깐(60초) 보여 준다. 클릭하면 서랍이 열린다.
@MainActor
final class TemporaryStatusItem: NSObject {
    var onClick: (() -> Void)?

    private var item: NSStatusItem?
    private var hideTask: Task<Void, Never>?

    func show(seconds: Int = 60) {
        if item == nil {
            let newItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let button = newItem.button {
                let image = NSImage(named: "MenuBarIcon")
                image?.isTemplate = true
                image?.accessibilityDescription = "TopTiroir"
                button.image = image
                button.target = self
                button.action = #selector(clicked)
                button.toolTip = String(localized: "TopTiroir 서랍 열기")
            }
            item = newItem
        }
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    @objc private func clicked() { onClick?() }
}
