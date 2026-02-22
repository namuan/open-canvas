import SwiftUI
#if os(macOS)
import AppKit
#endif

struct StatusBadge: View {
    let status: NodeStatus
    
    var body: some View {
        HStack(spacing: 6) {
            AnimatedStatusDot(status: status)
            
            Text(status.displayText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}
