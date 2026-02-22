import SwiftUI
#if os(macOS)
import AppKit
#endif

struct CanvasBackground: View {
    let style: CanvasBackgroundStyle
    let scale: CGFloat
    
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            switch style {
            case .dots:
                dotGrid
            case .lines:
                lineGrid
            case .none:
                EmptyView()
            }
        }
    }
    
    private var dotGrid: some View {
        let spacing: CGFloat = 30 * scale
        let dotSize: CGFloat = max(1, 2 * scale)
        
        return Canvas { context, size in
            let offsetX = spacing / 2
            let offsetY = spacing / 2
            
            for x in stride(from: offsetX, through: size.width, by: spacing) {
                for y in stride(from: offsetY, through: size.height, by: spacing) {
                    let rect = CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.secondary.opacity(0.25))
                    )
                }
            }
        }
    }
    
    private var lineGrid: some View {
        let spacing: CGFloat = 50 * scale
        
        return Canvas { context, size in
            context.stroke(
                Path { path in
                    var x: CGFloat = spacing / 2
                    while x < size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += spacing
                    }
                    
                    var y: CGFloat = spacing / 2
                    while y < size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += spacing
                    }
                },
                with: .color(.secondary.opacity(0.2)),
                lineWidth: max(0.5, 1 * scale)
            )
        }
    }
}
