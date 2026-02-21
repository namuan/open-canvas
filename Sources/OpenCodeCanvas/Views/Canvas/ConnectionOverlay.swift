import SwiftUI

struct ConnectionOverlay: View {
    let connections: [NodeConnection]
    let nodes: [CanvasNode]
    let scale: CGFloat
    let offset: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for connection in connections {
                    drawConnection(
                        connection: connection,
                        context: &context,
                        geometry: geometry
                    )
                }
            }
        }
    }
    
    private func drawConnection(
        connection: NodeConnection,
        context: inout GraphicsContext,
        geometry: GeometryProxy
    ) {
        guard let sourceNode = nodes.first(where: { $0.id == connection.sourceNodeID }),
              let targetNode = nodes.first(where: { $0.id == connection.targetNodeID }) else {
            return
        }
        
        let sourcePos = CGPoint(
            x: sourceNode.position.x * scale + offset.width + geometry.size.width / 2 + sourceNode.size.width * scale / 2,
            y: sourceNode.position.y * scale + offset.height + geometry.size.height / 2
        )
        
        let targetPos = CGPoint(
            x: targetNode.position.x * scale + offset.width + geometry.size.width / 2 - targetNode.size.width * scale / 2,
            y: targetNode.position.y * scale + offset.height + geometry.size.height / 2
        )
        
        let controlOffset: CGFloat = 80 * scale
        
        var path = Path()
        path.move(to: sourcePos)
        path.addCurve(
            to: targetPos,
            control1: CGPoint(x: sourcePos.x + controlOffset, y: sourcePos.y),
            control2: CGPoint(x: targetPos.x - controlOffset, y: targetPos.y)
        )
        
        context.stroke(
            path,
            with: .color(.white.opacity(0.4)),
            style: StrokeStyle(
                lineWidth: 2 * scale,
                lineCap: .round,
                dash: [5 * scale, 5 * scale]
            )
        )
    }
}
