import SwiftUI

struct NodeTitleBar: View {
    let title: String
    let sessionID: String?
    let onTitleChange: (String) -> Void
    let onMinimize: () -> Void
    let onToggleExpand: () -> Void
    let onClose: () -> Void
    
    @State private var isEditing = false
    @State private var editedTitle = ""
    @FocusState private var isTitleFocused: Bool
    @Environment(\.sessionFontSize) private var sessionFontSize
    
    var body: some View {
        HStack(spacing: 8) {
            trafficLightButton(color: .red, action: onClose, help: "Close")
            trafficLightButton(color: .yellow, action: onMinimize, help: "Minimize")
            trafficLightButton(color: .green, action: onToggleExpand, help: "Expand")

            if isEditing {
                TextField("Title", text: $editedTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: sessionFontSize, weight: .medium))
                    .foregroundStyle(.primary)
                    .focused($isTitleFocused)
                    .onSubmit {
                        commitTitleEdit()
                    }
                    .onExitCommand {
                        cancelTitleEdit()
                    }
            } else {
                Text(title)
                    .font(.system(size: sessionFontSize, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if !isEditing {
                Button {
                    startTitleEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: max(9, sessionFontSize - 2), weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Rename")
            }

            if let sessionID {
                Text(sessionID.truncated(to: 12))
                    .font(.system(size: max(9, sessionFontSize - 3), design: .monospaced))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(titleBarBackground)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onToggleExpand()
        }
    }

    private var titleBarBackground: some View {
        Color.ocTitleBackground
    }

    @ViewBuilder
    private func trafficLightButton(color: Color, action: @escaping () -> Void, help: String) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.2), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .help(help)
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
    
}
