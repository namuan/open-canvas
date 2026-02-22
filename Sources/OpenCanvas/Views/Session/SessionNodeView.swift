import SwiftUI

#if os(macOS)
import AppKit
#endif

#if os(macOS)
private func selectDirectory(prompt: String = "Select Directory", message: String = "Choose a working directory for this session") -> String? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = prompt
    panel.message = message
    panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
    return panel.runModal() == .OK ? panel.url?.path : nil
}
#endif

struct SessionNodeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: SessionNodeViewModel
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    @State private var showingColorPicker = false
    
    let node: CanvasNode
    
    private var effectiveFontSize: CGFloat {
        appState.isNodeMaximized(node.id) ? appState.expandedFontSize : appState.normalFontSize
    }
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
                    .environment(
                        \.sessionFontSize,
                        appState.isNodeMaximized(node.id) ? appState.expandedFontSize : appState.normalFontSize
                    )
            }
        }
        .background(nodeCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: node.isMinimized ? 8 : 10, style: .continuous)
                .fill(appState.isNodeSelected(node.id) ? Color.accentColor.opacity(0.08) : Color.clear)
                .animation(.easeInOut(duration: 0.15), value: appState.isNodeSelected(node.id))
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: node.isMinimized ? 8 : 10, style: .continuous)
                .stroke(selectionStroke, lineWidth: appState.isNodeSelected(node.id) ? 3 : 1)
                .animation(.easeInOut(duration: 0.15), value: appState.isNodeSelected(node.id))
                .allowsHitTesting(false)
        }
        .clipShape(.rect(cornerRadius: node.isMinimized ? 8 : 10))
        .scaleEffect(isDragging ? 1.02 : 1)
        .offset(dragOffset)
        .highPriorityGesture(dragGesture)
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
            viewModel.selectedDirectory = node.directory
        }
        .onChange(of: node.sessionID) { _, newSessionID in
            viewModel.configure(with: newSessionID)
        }
        .onChange(of: node.directory) { _, newDirectory in
            if viewModel.selectedDirectory != newDirectory {
                viewModel.selectedDirectory = newDirectory
            }
        }
        .onChange(of: viewModel.sessionID) { _, newSessionID in
            if let sessionID = newSessionID {
                appState.assignSession(nodeID: node.id, sessionID: sessionID)
            }
        }
        .onChange(of: viewModel.selectedDirectory) { _, newDirectory in
            appState.updateNodeDirectory(id: node.id, directory: newDirectory)
        }
    }
    
    private var nodeCardBackground: some View {
        Color.ocPanelBackground
    }
    
    private var selectionStroke: Color {
        appState.isNodeSelected(node.id) ? .accentColor : Color.ocBorder.opacity(0.6)
    }
    
    private var expandedView: some View {
        VStack(spacing: 0) {
            NodeTitleBar(
                title: node.title,
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
                    let isCurrentlyMaximized = appState.isNodeMaximized(node.id)
                    let spring: Animation = isCurrentlyMaximized
                        ? .spring(response: 0.36, dampingFraction: 0.82)
                        : .spring(response: 0.44, dampingFraction: 0.7)
                    withAnimation(spring) {
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
                .overlay(Color.ocBorder)
            
            Group {
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
                            },
                            onFocus: {
                                appState.clearSelection()
                            },
                            selectedDirectory: viewModel.selectedDirectory,
                            onChangeDirectory: {
                                #if os(macOS)
                                if let dir = selectDirectory(prompt: "Change Directory", message: "Choose a working directory for messages in this session") {
                                    viewModel.selectedDirectory = dir
                                }
                                #endif
                            }
                        )
                    }
                }
            }
            .simultaneousGesture(TapGesture().onEnded {
                appState.clearSelection()
            })
        }
        .frame(width: node.size.width, height: node.size.height)
        .onHover { hovering in
            appState.isHoveringOverSessionNode = hovering
        }
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
        .background(Color.ocTitleBackground)
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
                .foregroundStyle(.secondary)
            
            Text("No Active Session")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text("Create a session to begin messaging in this node.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            
            Button {
                #if os(macOS)
                if let directory = selectDirectory() {
                    Task { await viewModel.createSession(directory: directory) }
                }
                #else
                Task { await viewModel.createSession() }
                #endif
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
                .font(.system(size: max(10, effectiveFontSize - 1)))
                .lineLimit(2)
                .foregroundStyle(.primary)
            
            Spacer(minLength: 0)
            
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.ocPanelBackground)
    }
    
    private func permissionBanner(_ permission: PermissionRequestedData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Permission Required", systemImage: "hand.raised.fill")
                .font(.system(size: max(10, effectiveFontSize - 1), weight: .semibold))
            
            Text(permission.description)
                .font(.system(size: max(9, effectiveFontSize - 2)))
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
        .background(Color.ocComposerBackground)
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !appState.isNodeMaximized(node.id) else { return }
                if !isDragging {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                        isDragging = true
                    }
                }
                dragOffset = CGSize(
                    width: value.translation.width,
                    height: value.translation.height
                )
            }
            .onEnded { value in
                guard !appState.isNodeMaximized(node.id) else { return }
                
                let newPosition = CGPoint(
                    x: node.position.x + value.translation.width,
                    y: node.position.y + value.translation.height
                )
                appState.updateNodePosition(id: node.id, position: newPosition)

                dragOffset = .zero
                withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                    isDragging = false
                }
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
            #if os(macOS)
            if let directory = selectDirectory() {
                Task { await viewModel.createSession(directory: directory) }
            }
            #else
            Task { await viewModel.createSession() }
            #endif
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
