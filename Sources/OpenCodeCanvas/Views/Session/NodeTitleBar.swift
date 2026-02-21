import SwiftUI
import AppKit

struct NodeTitleBar: View {
    let title: String
    let color: NodeColor
    let status: NodeStatus
    let sessionID: String?
    let onTitleChange: (String) -> Void
    let onMinimize: () -> Void
    let onClose: () -> Void
    
    @State private var isEditing = false
    @State private var editedTitle = ""
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            statusIcon
            
            VStack(alignment: .leading, spacing: 2) {
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
                
                if let sessionID {
                    Text(sessionID.truncated(to: 18))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.74))
                }
            }
            
            Spacer(minLength: 0)
            
            if let sessionID {
                Button {
                    copySessionID(sessionID)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.8))
                .help("Copy session ID")
            }
            
            Button {
                onMinimize()
            } label: {
                Image(systemName: "rectangle.compress.vertical")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.8))
            .help("Minimize")
            
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.85))
            .help("Close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(titleBarBackground)
    }
    
    private var statusIcon: some View {
        Image(systemName: statusSymbol)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(color.primaryColor.opacity(0.55), in: .circle)
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.28), lineWidth: 1)
            }
    }
    
    private var titleBarBackground: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.42),
                color.primaryColor.opacity(0.24)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var statusSymbol: String {
        switch status {
        case .disconnected:
            return "bolt.slash"
        case .connecting:
            return "clock.arrow.circlepath"
        case .idle:
            return "bolt.horizontal.fill"
        case .running:
            return "waveform.path.ecg"
        case .error:
            return "exclamationmark.triangle.fill"
        }
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
