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
    var selectedDirectory: String? = nil
    var onChangeDirectory: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    @Environment(\.sessionFontSize) private var sessionFontSize
    
    private var directoryLabel: String {
        if let dir = selectedDirectory {
            return URL(fileURLWithPath: dir).lastPathComponent
        }
        return "No directory"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Directory indicator row
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                
                Text(directoryLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(selectedDirectory != nil ? .secondary : Color.orange)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                if let onChangeDirectory {
                    Button(action: onChangeDirectory) {
                        Text("Change")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Color.ocComposerBackground)
            .overlay(alignment: .top) { Divider().overlay(Color.ocBorder) }
            
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
        }
    }
}
