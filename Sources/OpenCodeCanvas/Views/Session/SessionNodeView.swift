import SwiftUI

#if os(macOS)
import AppKit
#endif

struct SessionNodeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: SessionNodeViewModel
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    @State private var showingColorPicker = false
    
    let node: CanvasNode
    
    init(node: CanvasNode) {
        self.node = node
        _viewModel = State(initialValue: SessionNodeViewModel(nodeID: node.id))
    }
    
    var body: some View {
        Group {
            if node.isMinimized {
                minimizedView
            } else {
                expandedView
            }
        }
        .background(nodeCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: node.isMinimized ? 18 : 22, style: .continuous)
                .stroke(selectionStroke, lineWidth: appState.isNodeSelected(node.id) ? 2 : 1)
        }
        .clipShape(.rect(cornerRadius: node.isMinimized ? 18 : 22))
        .shadow(
            color: node.color.primaryColor.opacity(appState.isNodeSelected(node.id) ? 0.32 : 0.18),
            radius: appState.isNodeSelected(node.id) ? 24 : 14,
            y: 12
        )
        .scaleEffect(isDragging ? 1.02 : 1)
        .offset(dragOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: isDragging)
        .animation(.easeInOut(duration: 0.2), value: appState.selectedNodeID)
        .animation(.easeInOut(duration: 0.2), value: appState.selectedNodeIDs)
        .gesture(dragGesture)
        .simultaneousGesture(longPressGesture)
        .contextMenu {
            nodeContextMenu
        }
        .onTapGesture {
            appState.selectNode(node.id)
            triggerSelectionHaptic()
        }
        .onAppear {
            viewModel.configure(with: node.sessionID)
        }
        .onChange(of: node.sessionID) { _, newSessionID in
            viewModel.configure(with: newSessionID)
        }
        .onChange(of: viewModel.sessionID) { _, newSessionID in
            if let sessionID = newSessionID {
                appState.assignSession(nodeID: node.id, sessionID: sessionID)
            }
        }
    }
    
    private var nodeCardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    node.color.primaryColor.opacity(0.95),
                    node.color.primaryColor.opacity(0.65),
                    Color.black.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.82))
        }
    }
    
    private var selectionStroke: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(appState.isNodeSelected(node.id) ? 0.75 : 0.35),
                node.color.primaryColor.opacity(appState.isNodeSelected(node.id) ? 0.9 : 0.45)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var expandedView: some View {
        VStack(spacing: 0) {
            NodeTitleBar(
                title: node.title,
                color: node.color,
                status: viewModel.status,
                sessionID: viewModel.sessionID,
                onTitleChange: { newTitle in
                    appState.updateNodeTitle(id: node.id, title: newTitle)
                },
                onMinimize: {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                        appState.toggleNodeMinimized(id: node.id)
                    }
                    triggerSelectionHaptic()
                },
                onToggleExpand: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        appState.toggleNodeMaximized(id: node.id)
                    }
                    triggerSelectionHaptic()
                },
                onClose: {
                    Task {
                        await appState.removeNode(id: node.id)
                    }
                }
            )
            
            Divider()
                .overlay(.white.opacity(0.15))
            
            if viewModel.status == .disconnected {
                disconnectedView
            } else {
                VStack(spacing: 0) {
                    MessageFeedView(messages: viewModel.messages)
                    
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }
                    
                    if let permission = viewModel.pendingPermission {
                        permissionBanner(permission)
                    }
                    
                    PromptBarView(
                        inputText: $viewModel.inputText,
                        isEnabled: viewModel.status == .idle,
                        isRunning: viewModel.status == .running,
                        onSend: {
                            Task {
                                await viewModel.sendMessage()
                            }
                        },
                        onAbort: {
                            Task {
                                await viewModel.abortGeneration()
                            }
                        }
                    )
                }
            }
        }
        .frame(width: node.size.width, height: node.size.height)
    }
    
    private var minimizedView: some View {
        HStack(spacing: 10) {
            AnimatedStatusDot(status: viewModel.status)
            
            Text(node.title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            
            Spacer(minLength: 0)
            
            StatusBadge(status: viewModel.status)
        }
        .padding(.horizontal, 16)
        .frame(width: 280, height: 72)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
                appState.toggleNodeMinimized(id: node.id)
            }
            triggerSelectionHaptic()
        }
    }
    
    private var disconnectedView: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 20)
            
            Image(systemName: "network.slash")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.76))
            
            Text("No Active Session")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            
            Text("Create a session to begin messaging in this node.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.72))
            
            Button {
                Task {
                    await viewModel.createSession()
                }
            } label: {
                Label("Create Session", systemImage: "plus.circle.fill")
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.status == .connecting)
            
            if viewModel.status == .connecting {
                ProgressView()
                    .controlSize(.small)
            }
            
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            
            Text(error)
                .font(.system(size: 12))
                .lineLimit(2)
                .foregroundStyle(.white)
            
            Spacer(minLength: 0)
            
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.68))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.black.opacity(0.26))
    }
    
    private func permissionBanner(_ permission: PermissionRequestedData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Permission Required", systemImage: "hand.raised.fill")
                .font(.system(size: 12, weight: .semibold))
            
            Text(permission.description)
                .font(.system(size: 11))
                .lineLimit(3)
            
            HStack(spacing: 10) {
                Button("Deny") {
                    Task {
                        await viewModel.respondToPermission(approved: false)
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Allow") {
                    Task {
                        await viewModel.respondToPermission(approved: true)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.22))
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !appState.isNodeMaximized(node.id) else { return }
                isDragging = true
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !appState.isNodeMaximized(node.id) else { return }
                isDragging = false
                dragOffset = .zero
                
                let newPosition = CGPoint(
                    x: node.position.x + value.translation.width / appState.canvasScale,
                    y: node.position.y + value.translation.height / appState.canvasScale
                )
                appState.updateNodePosition(id: node.id, position: newPosition)
            }
    }
    
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .onEnded { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                    appState.selectNode(node.id)
                }
                triggerSelectionHaptic()
            }
    }
    
    @ViewBuilder
    private var nodeContextMenu: some View {
        Button {
            Task {
                await viewModel.createSession()
            }
        } label: {
            if viewModel.sessionID == nil {
                Label("Create Session", systemImage: "plus.circle")
            } else {
                Label("Reconnect Session", systemImage: "arrow.clockwise")
            }
        }
        
        Button {
            appState.toggleNodeMinimized(id: node.id)
        } label: {
            Label(
                node.isMinimized ? "Expand" : "Minimize",
                systemImage: node.isMinimized ? "rectangle.expand.vertical" : "rectangle.compress.vertical"
            )
        }
        
        Divider()
        
        if viewModel.sessionID != nil {
            Button {
                viewModel.copySessionID()
            } label: {
                Label("Copy Session ID", systemImage: "doc.on.doc")
            }
            
            if viewModel.status == .running {
                Button {
                    Task {
                        await viewModel.abortGeneration()
                    }
                } label: {
                    Label("Abort", systemImage: "stop.circle")
                }
            }
        }
        
        Button {
            showingColorPicker = true
        } label: {
            Label("Change Color", systemImage: "paintpalette")
        }
        
        Button {
            appState.duplicateNode(id: node.id)
        } label: {
            Label("Duplicate Layout", systemImage: "square.on.square")
        }
        
        Divider()
        
        Button(role: .destructive) {
            Task {
                await appState.removeNode(id: node.id)
            }
        } label: {
            Label("Close", systemImage: "xmark.circle")
        }
    }
    
    private func triggerSelectionHaptic() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }
}
