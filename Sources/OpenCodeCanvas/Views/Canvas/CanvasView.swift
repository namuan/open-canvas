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
                
                ForEach(appState.nodes) { node in
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
                        .shadow(
                            color: appState.isNodeSelected(node.id) ? node.color.primaryColor.opacity(0.25) : .clear,
                            radius: 22
                        )
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: appState.selectedNodeID)
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: appState.selectedNodeIDs)
                }

                if let marqueeRect {
                    marqueeRectOverlay(marqueeRect)
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
                let worldPosition = CGPoint(
                    x: (value.location.x - geometry.size.width / 2 - appState.canvasOffset.width) / appState.canvasScale,
                    y: (value.location.y - geometry.size.height / 2 - appState.canvasOffset.height) / appState.canvasScale
                )
                
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    appState.addNode(at: worldPosition)
                }
            }
    }

    private var marqueeRect: CGRect? {
        guard let start = marqueeStartPoint, let current = marqueeCurrentPoint else { return nil }
        return normalizedRect(from: start, to: current)
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
