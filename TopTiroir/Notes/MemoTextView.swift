import AppKit
import SwiftUI

/// 메모 칸. Tab은 설정한 칸 수만큼 공백, Shift+Tab은 줄 앞 공백을 그만큼 줄인다.
/// SwiftUI TextEditor는 Tab 키를 바꿀 수 없어 NSTextView를 직접 쓴다.
struct MemoTextView: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let indentWidth: Int
    /// 값이 올라가면 메모 칸에 글자 커서를 둔다(맨 끝으로)
    var focusRequest = 0

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        guard let tv = scroll.documentView as? NSTextView else { return scroll }
        tv.delegate = context.coordinator
        tv.drawsBackground = false
        tv.isRichText = false
        tv.allowsUndo = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.textContainerInset = NSSize(width: 2, height: 4)
        tv.textColor = .labelColor
        tv.font = .systemFont(ofSize: fontSize)
        tv.string = text
        context.coordinator.lastFocusRequest = focusRequest
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tv = scroll.documentView as? NSTextView else { return }
        if tv.string != text { tv.string = text }          // 비우기 등 바깥에서 바뀐 경우
        if tv.font?.pointSize != fontSize { tv.font = .systemFont(ofSize: fontSize) }
        if focusRequest != context.coordinator.lastFocusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async {
                guard let window = tv.window else { return }
                window.makeKeyAndOrderFront(nil)
                window.makeFirstResponder(tv)
                tv.setSelectedRange(NSRange(location: (tv.string as NSString).length, length: 0))
                tv.scrollRangeToVisible(tv.selectedRange())
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MemoTextView
        var lastFocusRequest = 0

        init(_ parent: MemoTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertTab(_:)):
                textView.insertText(Indent.spaces(parent.indentWidth), replacementRange: textView.selectedRange())
                return true
            case #selector(NSResponder.insertBacktab(_:)):
                outdent(textView)
                return true
            default:
                return false
            }
        }

        /// 선택한 줄(들) 앞 공백을 너비만큼 줄인다. 되돌리기(⌘Z)가 되도록 shouldChangeText를 거친다.
        private func outdent(_ tv: NSTextView) {
            let ns = tv.string as NSString
            let lines = ns.lineRange(for: tv.selectedRange())
            let old = ns.substring(with: lines)
            let new = Indent.outdent(old, width: parent.indentWidth)
            guard new != old, tv.shouldChangeText(in: lines, replacementString: new) else { return }
            tv.replaceCharacters(in: lines, with: new)
            tv.didChangeText()
            tv.setSelectedRange(NSRange(location: lines.location, length: (new as NSString).length))
        }
    }
}
