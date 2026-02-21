import SwiftUI

struct AnimatedStatusDot: View {
    let status: NodeStatus
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .scaleEffect(status == .running ? (isAnimating ? 1.08 : 1.0) : 1.0)
            .animation(
                status == .running
                    ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                    : .default,
                value: isAnimating
            )
            .onAppear {
                if status == .running {
                    isAnimating = true
                }
            }
            .onChange(of: status) { _, newStatus in
                isAnimating = newStatus == .running
            }
    }
    
    private var statusColor: Color {
        switch status {
        case .disconnected:
            .gray
        case .connecting:
            .orange
        case .idle:
            .green
        case .running:
            .blue
        case .error:
            .red
        }
    }
}
