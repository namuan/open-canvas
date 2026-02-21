import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Image(systemName: "cpu")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .background(Color.blue.opacity(0.5))
                    .clipShape(.rect(cornerRadius: 6))
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                    .background(backgroundColor)
                    .clipShape(.rect(cornerRadius: 12))
                
                if message.isStreaming {
                    HStack(spacing: 4) {
                        LoadingDots()
                        Text("Generating...")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                
                if let toolUse = message.toolUse {
                    ToolUseCard(toolUse: toolUse)
                }
            }
            
            if message.role == .user {
                Image(systemName: "person")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .background(Color.green.opacity(0.5))
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
            Color.white.opacity(0.15)
        case .assistant:
            Color.white.opacity(0.08)
        case .system:
            Color.white.opacity(0.05)
        }
    }
}
