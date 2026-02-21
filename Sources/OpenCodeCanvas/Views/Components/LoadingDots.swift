import SwiftUI

struct LoadingDots: View {
    @State private var animatingDot = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(.white.opacity(0.7))
                    .frame(width: 6, height: 6)
                    .scaleEffect(animatingDot == index ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.3)
                            .repeatForever(autoreverses: true),
                        value: animatingDot
                    )
            }
        }
        .onAppear {
            Task {
                while true {
                    try? await Task.sleep(for: .seconds(0.3))
                    await MainActor.run {
                        animatingDot = (animatingDot + 1) % 3
                    }
                }
            }
        }
    }
}
