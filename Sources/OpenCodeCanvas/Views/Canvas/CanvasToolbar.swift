import SwiftUI

struct CanvasToolbar: ToolbarContent {
    @Environment(AppState.self) private var appState
    @Binding var showingSettings: Bool
    
    var body: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                appState.addNode()
            } label: {
                Label("Add Node", systemImage: "plus.square")
            }
            .help("Add new session node (⌘N)")
            
            Button {
                appState.autoLayout()
            } label: {
                Label("Auto Layout", systemImage: "square.grid.3x3")
            }
            .help("Auto-arrange nodes (⌘⇧L)")
            
            Divider()
            
            Button {
                appState.zoomOut()
            } label: {
                Label("Zoom Out", systemImage: "minus.magnifyingglass")
            }
            .help("Zoom out (⌘-)")
            
            Text("\(Int(appState.canvasScale * 100))%")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 45)
            
            Button {
                appState.zoomIn()
            } label: {
                Label("Zoom In", systemImage: "plus.magnifyingglass")
            }
            .help("Zoom in (⌘+)")
            
            Button {
                appState.resetView()
            } label: {
                Label("Reset View", systemImage: "arrow.counterclockwise")
            }
            .help("Reset view (⌘0)")
            
            Divider()
            
            HStack(spacing: 4) {
                Circle()
                    .fill(OpenCodeServerManager.shared.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(OpenCodeServerManager.shared.serverURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onTapGesture {
                showingSettings = true
            }
            .help("Server status - click to open settings")
            
            Text("\(appState.activeSessionCount)/\(appState.nodes.count)")
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .clipShape(.rect(cornerRadius: 4))
                .help("Active/Total sessions")
        }
    }
}
