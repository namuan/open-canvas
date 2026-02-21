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
                        .frame(
                            width: node.isMinimized ? 280 : node.size.width * appState.canvasScale,
                            height: node.isMinimized ? 72 : node.size.height * appState.canvasScale
                        )
                        .shadow(
                            color: appState.selectedNodeID == node.id ? node.color.primaryColor.opacity(0.25) : .clear,
                            radius: 22
                        )
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: appState.selectedNodeID)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .overlay(alignment: .topLeading) {
                canvasHeader
                    .padding(16)
            }
            .overlay(alignment: .bottomTrailing) {
                canvasScaleControl
                    .padding(18)
            }
            .gesture(canvasDragGesture)
            .simultaneousGesture(canvasZoomGesture)
            .simultaneousGesture(doubleTapToAddNode(geometry: geometry))
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
    
    private var canvasHeader: some View {
        HStack(spacing: 14) {
            Label("Canvas", systemImage: "view.3d")
                .font(.system(size: 14, weight: .semibold))
            
            Divider()
                .frame(height: 14)
            
            Label("\(appState.nodes.count)", systemImage: "square.stack.3d.up")
                .font(.system(size: 12, weight: .medium))
            
            Label("\(appState.activeSessionCount)", systemImage: "bolt.horizontal.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }
    
    private var canvasScaleControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                Text("Zoom")
                Spacer(minLength: 12)
                Text("\(Int(appState.canvasScale * 100))%")
                    .font(.system(size: 11, design: .monospaced))
            }
            .font(.system(size: 12, weight: .medium))
            
            Slider(
                value: Binding(
                    get: { appState.canvasScale },
                    set: { appState.updateCanvasScale($0) }
                ),
                in: 0.3...2.5
            )
            .frame(width: 170)
        }
        .padding(12)
        .background(.thinMaterial, in: .rect(cornerRadius: 12))
    }
    
    private var canvasDragGesture: some Gesture {
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
    
    private var canvasZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                let newScale = min(2.5, max(0.3, scale))
                appState.updateCanvasScale(newScale)
            }
    }
    
    private func doubleTapToAddNode(geometry: GeometryProxy) -> some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { value in
                let worldPosition = CGPoint(
                    x: (value.location.x - geometry.size.width / 2 - appState.canvasOffset.width) / appState.canvasScale,
                    y: (value.location.y - geometry.size.height / 2 - appState.canvasOffset.height) / appState.canvasScale
                )
                
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    appState.addNode(at: worldPosition)
                }
            }
    }
}
