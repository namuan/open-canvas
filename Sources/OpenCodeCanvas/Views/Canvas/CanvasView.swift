import SwiftUI
#if os(macOS)
import AppKit
#endif

struct CanvasView: View {
    @Environment(AppState.self) private var appState
    @State private var isDraggingCanvas = false
    @State private var dragStartOffset: CGSize = .zero
    @State private var isMarqueeSelecting = false
    @State private var marqueeStartPoint: CGPoint?
    @State private var marqueeCurrentPoint: CGPoint?
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
                
                ForEach(Array(appState.nodes.enumerated()), id: \.element.id) { index, node in
                    SessionNodeView(node: node)
                        .position(
                            x: node.position.x * appState.canvasScale + appState.canvasOffset.width + geometry.size.width / 2,
                            y: node.position.y * appState.canvasScale + appState.canvasOffset.height + geometry.size.height / 2
                        )
                        .scaleEffect(appState.canvasScale, anchor: .center)
                        .frame(
                            width: node.isMinimized ? 280 : node.size.width,
                            height: node.isMinimized ? 72 : node.size.height
                        )
                        .zIndex(zIndexForNode(node, index: index))
                }

                if let marqueeRect {
                    marqueeRectOverlay(marqueeRect)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            #if os(macOS)
            .overlay {
                TrackpadScrollCaptureView { delta in
                    guard !isMarqueeSelecting else { return }

                    let newOffset = CGSize(
                        width: appState.canvasOffset.width + delta.width,
                        height: appState.canvasOffset.height + delta.height
                    )
                    appState.updateCanvasOffset(newOffset)
                }
                .allowsHitTesting(false)
            }
            #endif
            .gesture(canvasDragGesture)
            .simultaneousGesture(canvasZoomGesture)
            .simultaneousGesture(doubleTapToAddNode(geometry: geometry))
            .onTapGesture {
                appState.clearSelection()
            }
            .onAppear {
                appState.updateCanvasViewportSize(geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                appState.updateCanvasViewportSize(newSize)
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
    
    private var canvasDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if shouldUseMarqueeSelection() || isMarqueeSelecting {
                    if !isMarqueeSelecting {
                        isMarqueeSelecting = true
                        marqueeStartPoint = value.startLocation
                    }

                    marqueeCurrentPoint = value.location
                    updateMarqueeSelection()
                    return
                }

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
                if isMarqueeSelecting {
                    updateMarqueeSelection()
                    isMarqueeSelecting = false
                    marqueeStartPoint = nil
                    marqueeCurrentPoint = nil
                    return
                }

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
                guard !isPointInsideAnyNode(value.location, in: geometry.size) else {
                    return
                }

                let worldPosition = CGPoint(
                    x: (value.location.x - geometry.size.width / 2 - appState.canvasOffset.width) / appState.canvasScale,
                    y: (value.location.y - geometry.size.height / 2 - appState.canvasOffset.height) / appState.canvasScale
                )
                
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    appState.addNode(at: worldPosition)
                }
            }
    }

    private func isPointInsideAnyNode(_ point: CGPoint, in viewportSize: CGSize) -> Bool {
        for node in appState.nodes {
            let width = (node.isMinimized ? 280 : node.size.width) * appState.canvasScale
            let height = (node.isMinimized ? 72 : node.size.height) * appState.canvasScale
            let center = CGPoint(
                x: node.position.x * appState.canvasScale + appState.canvasOffset.width + viewportSize.width / 2,
                y: node.position.y * appState.canvasScale + appState.canvasOffset.height + viewportSize.height / 2
            )

            let rect = CGRect(
                x: center.x - width / 2,
                y: center.y - height / 2,
                width: width,
                height: height
            )

            if rect.contains(point) {
                return true
            }
        }

        return false
    }

    private var marqueeRect: CGRect? {
        guard let start = marqueeStartPoint, let current = marqueeCurrentPoint else { return nil }
        return normalizedRect(from: start, to: current)
    }

    private func zIndexForNode(_ node: CanvasNode, index: Int) -> Double {
        if appState.isNodeMaximized(node.id) {
            return 10_000
        }
        if appState.isNodeSelected(node.id) {
            return 1_000 + Double(index)
        }
        return Double(index)
    }

    private func marqueeRectOverlay(_ rect: CGRect) -> some View {
        Rectangle()
            .fill(Color.accentColor.opacity(0.14))
            .overlay(
                Rectangle()
                    .stroke(
                        Color.accentColor.opacity(0.9),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }

    private func updateMarqueeSelection() {
        guard let rectInView = marqueeRect else {
            appState.clearSelection()
            return
        }

        let worldRect = worldRect(fromViewRect: rectInView)
        let selectedIDs = Set(
            appState.nodes
                .filter { nodeWorldRect($0).intersects(worldRect) }
                .map(\.id)
        )
        appState.selectNodes(selectedIDs)
    }

    private func worldRect(fromViewRect rect: CGRect) -> CGRect {
        let topLeft = CGPoint(
            x: (rect.minX - appState.canvasOffset.width - appState.canvasViewportSize.width / 2) / appState.canvasScale,
            y: (rect.minY - appState.canvasOffset.height - appState.canvasViewportSize.height / 2) / appState.canvasScale
        )
        let bottomRight = CGPoint(
            x: (rect.maxX - appState.canvasOffset.width - appState.canvasViewportSize.width / 2) / appState.canvasScale,
            y: (rect.maxY - appState.canvasOffset.height - appState.canvasViewportSize.height / 2) / appState.canvasScale
        )
        return normalizedRect(from: topLeft, to: bottomRight)
    }

    private func nodeWorldRect(_ node: CanvasNode) -> CGRect {
        let width = node.isMinimized ? 280 : node.size.width
        let height = node.isMinimized ? 72 : node.size.height
        return CGRect(
            x: node.position.x - width / 2,
            y: node.position.y - height / 2,
            width: width,
            height: height
        )
    }

    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func shouldUseMarqueeSelection() -> Bool {
        #if os(macOS)
        NSEvent.modifierFlags.contains(.shift)
        #else
        false
        #endif
    }
}
