import SwiftUI

struct SessionNodeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: SessionNodeViewModel
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    @State private var showingColorPicker = false
    @State private var showingContextMenu = false
    
    let node: CanvasNode
    
    init(node: CanvasNode) {
        self.node = node
        self._viewModel = State(initialValue: SessionNodeViewModel(nodeID: node.id))
    }
    
    var body: some View {
        Group {
            if node.isMinimized {
                minimizedView
            } else {
                expandedView
            }
        }
        .background(node.color.gradient)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(
            color: node.color.primaryColor.opacity(appState.selectedNodeID == node.id ? 0.6 : 0.4),
            radius: appState.selectedNodeID == node.id ? 30 : 24
        )
        .scaleEffect(isDragging ? 1.03 : 1.0)
        .offset(dragOffset)
        .animation(.spring(response: 0.3), value: isDragging)
        .gesture(dragGesture)
        .simultaneousGesture(longPressGesture)
        .contextMenu {
            nodeContextMenu
        }
        .onTapGesture {
            appState.selectedNodeID = node.id
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
                    appState.toggleNodeMinimized(id: node.id)
                },
                onClose: {
                    Task {
                        await appState.removeNode(id: node.id)
                    }
                }
            )
            
            Divider()
                .background(.white.opacity(0.2))
            
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
        HStack(spacing: 12) {
            AnimatedStatusDot(status: viewModel.status)
            
            Text(node.title)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
            
            Spacer()
            
            StatusBadge(status: viewModel.status)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 220, height: 60)
        .onTapGesture(count: 2) {
            appState.toggleNodeMinimized(id: node.id)
        }
    }
    
    private var disconnectedView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "rectangle.dashed.badge.record")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.5))
            
            Text("No Active Session")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            
            Button {
                Task {
                    await viewModel.createSession()
                }
            } label: {
                Text("Create Session")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.2))
                    .clipShape(.rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.status == .connecting)
            
            if viewModel.status == .connecting {
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            
            Text(error)
                .font(.system(size: 12))
                .lineLimit(2)
                .foregroundStyle(.white)
            
            Spacer()
            
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.red.opacity(0.3))
    }
    
    private func permissionBanner(_ permission: PermissionRequestedData) -> some View {
        VStack(spacing: 8) {
            Text("Permission Required")
                .font(.system(size: 12, weight: .semibold))
            
            Text(permission.description)
                .font(.system(size: 11))
                .lineLimit(3)
            
            HStack(spacing: 12) {
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
        .background(.yellow.opacity(0.3))
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation
            }
            .onEnded { value in
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    appState.selectedNodeID = node.id
                }
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
            Label(node.isMinimized ? "Expand" : "Minimize", systemImage: node.isMinimized ? "arrow.up.left.and.arrow.down.right" : "minus.rectangle")
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
}
