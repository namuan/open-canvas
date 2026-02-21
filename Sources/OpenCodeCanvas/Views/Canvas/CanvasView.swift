import SwiftUI

struct CanvasView: View {
    @Environment(AppState.self) private var appState
    @State private var isDraggingCanvas = false
    @State private var dragStartOffset: CGSize = .zero
    @State private var showingSettings = false
    @State private var showingClearConfirmation = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CanvasBackground(
                    style: appState.canvasBackgroundStyle,
                    scale: appState.canvasScale
                )
                
                ConnectionOverlay(
                    connections: appState.connections,
                    nodes: appState.nodes,
                    scale: appState.canvasScale,
                    offset: appState.canvasOffset
                )
                
                ForEach(appState.nodes) { node in
                    SessionNodeView(node: node)
                        .position(
                            x: node.position.x * appState.canvasScale + appState.canvasOffset.width + geometry.size.width / 2,
                            y: node.position.y * appState.canvasScale + appState.canvasOffset.height + geometry.size.height / 2
                        )
                        .frame(width: node.isMinimized ? 220 : node.size.width * appState.canvasScale, height: node.isMinimized ? 60 : node.size.height * appState.canvasScale)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(canvasDragGesture(geometry: geometry))
            .gesture(canvasZoomGesture(geometry: geometry))
            .onTapGesture {
                appState.selectedNodeID = nil
            }
        }
        .toolbar {
            CanvasToolbar(
                showingSettings: $showingSettings,
                showingClearConfirmation: $showingClearConfirmation
            )
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .confirmationDialog(
            "Clear Canvas",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Nodes", role: .destructive) {
                appState.clearCanvas()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all session nodes. This action cannot be undone.")
        }
    }
    
    private func canvasDragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDraggingCanvas {
                    isDraggingCanvas = true
                    dragStartOffset = appState.canvasOffset
                }
                
                let newOffset = CGSize(
                    width: dragStartOffset.width + value.translation.width,
                    height: dragStartOffset.height + value.translation.height
                )
                appState.updateCanvasOffset(newOffset)
            }
            .onEnded { _ in
                isDraggingCanvas = false
            }
    }
    
    private func canvasZoomGesture(geometry: GeometryProxy) -> some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                let newScale = min(2.5, max(0.3, scale))
                appState.updateCanvasScale(newScale)
            }
    }
}
