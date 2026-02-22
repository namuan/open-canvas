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
    @State private var canvasViewSize: CGSize = .zero
    @State private var zoomStartScale: CGFloat?
    @State private var showingSettings = false
    @State private var showingClearConfirmation = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CanvasBackground(
                    style: appState.canvasBackgroundStyle,
                    scale: appState.canvasScale
                )
                
                ForEach(Array(appState.nodes.enumerated()), id: \.element.id) { index, node in
                    let baseWidth = node.isMinimized ? 280.0 : node.size.width
                    let baseHeight = node.isMinimized ? 72.0 : node.size.height
                    SessionNodeView(node: node)
                        .frame(width: baseWidth, height: baseHeight)
                        .scaleEffect(appState.canvasScale, anchor: .center)
                        .frame(
                            width: baseWidth * appState.canvasScale,
                            height: baseHeight * appState.canvasScale
                        )
                        .position(
                            x: node.position.x * appState.canvasScale + appState.canvasOffset.width + geometry.size.width / 2,
                            y: node.position.y * appState.canvasScale + appState.canvasOffset.height + geometry.size.height / 2
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
                TrackpadScrollCaptureView(isBlocked: showingSettings || showingClearConfirmation) { delta in
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
            .gesture(canvasDragGesture, including: .gesture)
            .simultaneousGesture(canvasZoomGesture)
            .simultaneousGesture(doubleTapToAddNode(geometry: geometry))
            .onTapGesture {
                appState.clearSelection()
            }
            .onAppear {
                canvasViewSize = geometry.size
                appState.updateCanvasViewportSize(geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                canvasViewSize = newSize
                appState.updateCanvasViewportSize(newSize)
            }
        }
        .toolbar {
            CanvasToolbar(
                showingSettings: $showingSettings
            )
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(appState)
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
                if zoomStartScale == nil {
                    zoomStartScale = appState.canvasScale
                }

                let baseline = zoomStartScale ?? appState.canvasScale
                let newScale = min(2.5, max(0.3, baseline * scale))
                appState.updateCanvasScale(newScale)
            }
            .onEnded { _ in
                zoomStartScale = nil
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

        guard canvasViewSize.width > 0, canvasViewSize.height > 0 else {
            appState.clearSelection()
            return
        }

        var selectedIDs = Set<UUID>()
        for node in appState.nodes {
            let nodeRect = nodeViewRect(node, in: canvasViewSize)
            if nodeRect.intersects(rectInView) {
                selectedIDs.insert(node.id)
            }
        }
        appState.selectNodes(selectedIDs)
    }

    private func nodeViewRect(_ node: CanvasNode, in viewportSize: CGSize) -> CGRect {
        let width = (node.isMinimized ? 280 : node.size.width) * appState.canvasScale
        let height = (node.isMinimized ? 72 : node.size.height) * appState.canvasScale
        let center = CGPoint(
            x: node.position.x * appState.canvasScale + appState.canvasOffset.width + viewportSize.width / 2,
            y: node.position.y * appState.canvasScale + appState.canvasOffset.height + viewportSize.height / 2
        )
        return CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
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
