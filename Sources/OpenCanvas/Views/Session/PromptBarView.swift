import SwiftUI
#if os(macOS)
import AppKit
#endif

struct PromptBarView: View {
    @Binding var inputText: String
    let isEnabled: Bool
    let isRunning: Bool
    let onSend: () -> Void
    let onAbort: () -> Void
    var onFocus: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    @Environment(\.sessionFontSize) private var sessionFontSize
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextEditor(text: $inputText)
                .font(.system(size: sessionFontSize))
                .foregroundStyle(.primary)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .frame(minHeight: 36, maxHeight: 100)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.ocInputBackground)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.ocBorder, lineWidth: 1)
                )
                .disabled(!isEnabled || isRunning)
                .onChange(of: isFocused) { _, focused in
                    if focused { onFocus?() }
                }
            
            if isRunning {
                Button {
                    onAbort()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: sessionFontSize + 7))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Stop generation")
            } else {
                Button {
                    onSend()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: sessionFontSize + 7))
                        .foregroundStyle(isEnabled && !inputText.isBlank ? .blue : .gray)
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled || inputText.isBlank)
                .help("Send message (⌘↩)")
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(12)
        .background(Color.ocComposerBackground)
        .overlay(alignment: .top) {
            Divider().overlay(Color.ocBorder)
        }
    }
}
