import SwiftUI

struct PromptBarView: View {
    @Binding var inputText: String
    let isEnabled: Bool
    let isRunning: Bool
    let onSend: () -> Void
    let onAbort: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextEditor(text: $inputText)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .frame(minHeight: 36, maxHeight: 100)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.3))
                .clipShape(.rect(cornerRadius: 8))
                .disabled(!isEnabled || isRunning)
            
            if isRunning {
                Button {
                    onAbort()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Stop generation")
            } else {
                Button {
                    onSend()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(isEnabled && !inputText.isBlank ? .blue : .gray)
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled || inputText.isBlank)
                .help("Send message (⌘↩)")
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(12)
        .background(.black.opacity(0.4))
    }
}
