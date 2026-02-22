import SwiftUI
#if os(macOS)
import AppKit
#endif

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Image(systemName: "cpu")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.ocComposerBackground)
                    .clipShape(.rect(cornerRadius: 6))
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                    .background(backgroundColor)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.ocBorder, lineWidth: 1)
                    )
                
                if message.isStreaming {
                    HStack(spacing: 4) {
                        LoadingDots()
                        Text("Generating...")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let toolUse = message.toolUse {
                    ToolUseCard(toolUse: toolUse)
                }
            }
            
            if message.role == .user {
                Image(systemName: "person")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.ocComposerBackground)
                    .clipShape(.rect(cornerRadius: 6))
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }
    
    private var backgroundColor: Color {
        switch message.role {
        case .user:
            Color.ocBubbleUserBackground
        case .assistant:
            Color.ocBubbleAssistantBackground
        case .system:
            Color.ocBubbleSystemBackground
        }
    }
}
