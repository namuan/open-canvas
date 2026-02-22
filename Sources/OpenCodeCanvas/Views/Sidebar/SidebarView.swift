import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    
    var body: some View {
        List(selection: selectedNodeID) {
            Section("Quick Actions") {
                Button {
                    appState.addNode()
                } label: {
                    Label("New Session Node", systemImage: "plus.circle")
                }

                Button {
                    appState.selectAllNodes()
                } label: {
                    Label("Select All Sessions", systemImage: "checklist")
                }
                .disabled(appState.nodes.isEmpty)

                Button {
                    Task {
                        await appState.deleteSelectedNodes()
                    }
                } label: {
                    Label("Delete Selected", systemImage: "trash")
                }
                .disabled(!appState.hasSelection)
                
                Button {
                    appState.autoLayout()
                } label: {
                    Label("Re-Layout Selection", systemImage: "square.grid.3x3")
                }
                
                Button {
                    appState.resetView()
                } label: {
                    Label("Reset Viewport", systemImage: "scope")
                }
            }
            
            Section("Sessions") {
                if filteredNodes.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "sparkles.rectangle.stack",
                        description: Text("Create a new node to start a session.")
                    )
                }
                
                ForEach(filteredNodes) { node in
                    SidebarNodeCell(node: node)
                        .tag(node.id)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await appState.removeNode(id: node.id)
                                }
                            } label: {
                                Label("Close", systemImage: "trash")
                            }
                            
                            Button {
                                appState.duplicateNode(id: node.id)
                            } label: {
                                Label("Duplicate", systemImage: "square.on.square")
                            }
                            .tint(.indigo)
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "Search sessions")
        .safeAreaInset(edge: .bottom) {
            footerStats
                .padding(12)
        }
    }
    
    private var selectedNodeID: Binding<UUID?> {
        Binding(
            get: { appState.selectedNodeID },
            set: { newValue in
                if let newValue {
                    appState.selectNode(newValue)
                } else {
                    appState.clearSelection()
                }
            }
        )
    }
    
    private var filteredNodes: [CanvasNode] {
        guard !searchText.isEmpty else {
            return appState.nodes
        }
        
        return appState.nodes.filter {
            $0.title.localizedStandardContains(searchText) ||
            ($0.sessionID?.localizedStandardContains(searchText) ?? false)
        }
    }
    
    private var footerStats: some View {
        HStack(spacing: 12) {
            Label("\(appState.activeSessionCount)", systemImage: "bolt.fill")
                .font(.system(size: 12, weight: .semibold))
            
            Divider()
                .frame(height: 12)
            
            Label("\(appState.nodes.count)", systemImage: "square.stack.3d.up")
                .font(.system(size: 12, weight: .semibold))
            
            Spacer(minLength: 0)
            
            Text(OpenCodeServerManager.shared.isConnected ? "Online" : "Offline")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(OpenCodeServerManager.shared.isConnected ? .green : .orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}

private struct SidebarNodeCell: View {
    let node: CanvasNode
    
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(node.color.primaryColor.gradient)
                .frame(width: 10, height: 24)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(node.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                
                Text(secondaryText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
            
            Image(systemName: node.sessionID == nil ? "bolt.slash" : "bolt.horizontal.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(node.sessionID == nil ? Color.secondary : Color.green)
        }
        .padding(.vertical, 2)
    }
    
    private var secondaryText: String {
        if let sessionID = node.sessionID {
            return sessionID.truncated(to: 12)
        }
        return "No session"
    }
}
