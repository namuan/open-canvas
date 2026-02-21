import SwiftUI

struct NodeTitleBar: View {
    let title: String
    let color: NodeColor
    let status: NodeStatus
    let sessionID: String?
    let onTitleChange: (String) -> Void
    let onMinimize: () -> Void
    let onClose: () -> Void
    
    @State private var isEditing = false
    @State private var editedTitle: String = ""
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 3)
            }
            
            AnimatedStatusDot(status: status)
            
            if isEditing {
                TextField("Title", text: $editedTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .focused($isTitleFocused)
                    .onSubmit {
                        commitTitleEdit()
                    }
                    .onExitCommand {
                        cancelTitleEdit()
                    }
            } else {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .onTapGesture(count: 2) {
                        startTitleEdit()
                    }
            }
            
            Spacer()
            
            if let sessionID = sessionID {
                Button {
                    copySessionID(sessionID)
                } label: {
                    Text(sessionID.truncated(to: 8))
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.2))
                        .clipShape(.rect(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("Click to copy session ID")
            }
            
            Button {
                onMinimize()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .background(Color.yellow)
                    .clipShape(.rect(cornerRadius: 2))
            }
            .buttonStyle(.plain)
            .help("Minimize")
            
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .background(Color.red)
                    .clipShape(.rect(cornerRadius: 2))
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.3))
    }
    
    private func startTitleEdit() {
        editedTitle = title
        isEditing = true
        isTitleFocused = true
    }
    
    private func commitTitleEdit() {
        if !editedTitle.trimmed.isEmpty {
            onTitleChange(editedTitle.trimmed)
        }
        isEditing = false
    }
    
    private func cancelTitleEdit() {
        isEditing = false
        editedTitle = title
    }
    
    private func copySessionID(_ id: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(id, forType: .string)
    }
}
