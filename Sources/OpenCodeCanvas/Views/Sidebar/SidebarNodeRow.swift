import SwiftUI

struct SidebarNodeRow: View {
    let node: CanvasNode
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(node.color.primaryColor)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(node.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(lastActivityText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            StatusBadge(status: nodeStatus)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .clipShape(.rect(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
    
    private var nodeStatus: NodeStatus {
        node.sessionID != nil ? .idle : .disconnected
    }
    
    private var lastActivityText: String {
        if let lastActivity = node.lastActivity {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: lastActivity, relativeTo: Date())
        }
        return "No activity"
    }
}
