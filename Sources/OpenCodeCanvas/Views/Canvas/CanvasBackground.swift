import SwiftUI

struct CanvasBackground: View {
    let style: CanvasBackgroundStyle
    let scale: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.07, blue: 0.11),
                        Color(red: 0.03, green: 0.04, blue: 0.07),
                        Color(red: 0.08, green: 0.13, blue: 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                Circle()
                    .fill(Color.cyan.opacity(0.08))
                    .frame(width: geometry.size.width * 0.7)
                    .blur(radius: 30)
                    .offset(x: geometry.size.width * 0.2, y: -geometry.size.height * 0.3)
                
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
                        with: .color(.white.opacity(0.14))
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
                with: .color(.white.opacity(0.09)),
                lineWidth: max(0.5, 1 * scale)
            )
        }
    }
}
