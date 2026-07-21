import SwiftUI
import UIKit

/// A UITextView-backed code editor with syntax highlighting and code-friendly
/// input settings (no autocorrect, no smart quotes, monospaced).
///
/// Highlighting is applied on load, on external changes, and when editing ends.
/// It is intentionally NOT re-applied on every keystroke — resetting
/// `attributedText` mid-typing is a well-known source of cursor-jump bugs, so we
/// keep typing snappy and re-color on blur.
struct CodeEditorView: UIViewRepresentable {
    @Binding var text: String
    let language: Language

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = UIColor(hex: "0E1117")
        view.tintColor = UIColor(hex: "7AA2F7")
        view.autocapitalizationType = .none
        view.autocorrectionType = .no
        view.spellCheckingType = .no
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.keyboardType = .asciiCapable
        view.alwaysBounceVertical = true
        view.keyboardDismissMode = .interactive
        view.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 220, right: 8)
        view.typingAttributes = Self.baseAttributes
        view.attributedText = SyntaxHighlighter(language: language).attributed(for: text)
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        // Rebuild only for external changes (file switch, agent edit); user
        // keystrokes already flowed to the binding via textViewDidChange, so the
        // guard is false and the cursor is left alone.
        if uiView.text != text {
            let selected = uiView.selectedRange
            uiView.attributedText = SyntaxHighlighter(language: language).attributed(for: text)
            let length = (uiView.text as NSString).length
            uiView.selectedRange = NSRange(location: min(selected.location, length), length: 0)
        }
    }

    private static var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: UIFont.monospacedSystemFont(ofSize: 15, weight: .regular),
         .foregroundColor: UIColor(hex: "E6EDF3")]
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CodeEditorView
        init(_ parent: CodeEditorView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            let selected = textView.selectedRange
            textView.attributedText = SyntaxHighlighter(language: parent.language)
                .attributed(for: textView.text)
            let length = (textView.text as NSString).length
            textView.selectedRange = NSRange(location: min(selected.location, length), length: 0)
        }
    }
}
