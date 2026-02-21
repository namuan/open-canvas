import SwiftUI

struct StatusBadge: View {
    let status: NodeStatus
    
    var body: some View {
        HStack(spacing: 6) {
            AnimatedStatusDot(status: status)
            
            Text(status.displayText)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .clipShape(.rect(cornerRadius: 8))
    }
    
    private var backgroundColor: Color {
        switch status {
        case .disconnected:
            Color.gray.opacity(0.3)
        case .connecting:
            Color.orange.opacity(0.3)
        case .idle:
            Color.green.opacity(0.3)
        case .running:
            Color.blue.opacity(0.3)
        case .error:
            Color.red.opacity(0.3)
        }
    }
}
