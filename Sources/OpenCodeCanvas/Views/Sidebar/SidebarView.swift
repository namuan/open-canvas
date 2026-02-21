import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(appState.nodes) { node in
                        SidebarNodeRow(
                            node: node,
                            isSelected: appState.selectedNodeID == node.id,
                            onSelect: {
                                appState.selectedNodeID = node.id
                            }
                        )
                    }
                }
                .padding(8)
            }
        }
        .frame(minWidth: 200, maxWidth: 280)
        .background(.ultraThinMaterial)
    }
    
    private var header: some View {
        HStack {
            Text("Sessions")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text("\(appState.activeSessionCount)/\(appState.nodes.count)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
