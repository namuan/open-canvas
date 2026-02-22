import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)
            
            actionRow
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            
            searchBar
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            
            Divider()
            
            ScrollView {
                if filteredNodes.isEmpty {
                    emptyState
                        .padding(.horizontal, 14)
                        .padding(.top, 24)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredNodes) { node in
                            SidebarNodeCard(
                                node: node,
                                isSelected: appState.isNodeSelected(node.id),
                                onSelect: { appState.selectNode(node.id) },
                                onDuplicate: { appState.duplicateNode(id: node.id) },
                                onDelete: {
                                    Task {
                                        await appState.removeNode(id: node.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                }
            }
            
            Divider()
            
            footerStats
                .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
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
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("OpenCanvas")
                .font(.system(size: 18, weight: .bold))
            
            Text("\(appState.nodes.count) sessions")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var actionRow: some View {
        HStack(spacing: 8) {
            actionButton(
                title: "New",
                symbol: "plus",
                isProminent: true
            ) {
                appState.addNode()
            }
            
            actionButton(title: "Layout", symbol: "square.grid.3x3") {
                appState.autoLayout()
            }
            
            actionButton(title: "Reset", symbol: "scope") {
                appState.resetView()
            }
            .disabled(appState.nodes.isEmpty)
        }
    }
    
    private func actionButton(
        title: String,
        symbol: String,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(
            Group {
                if isProminent {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.accentColor.opacity(0.16))
                } else {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search sessions", text: $searchText)
                .textFieldStyle(.plain)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
    
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
            
            Text("No sessions yet")
                .font(.system(size: 14, weight: .semibold))
            
            Text("Create a new session to start working on the canvas.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
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

private struct SidebarNodeCard: View {
    let node: CanvasNode
    let isSelected: Bool
    let onSelect: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(node.color.primaryColor.gradient)
                    .frame(width: 10, height: 30)
                
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
                
                VStack(alignment: .trailing, spacing: 5) {
                    Image(systemName: node.sessionID == nil ? "bolt.slash" : "bolt.horizontal.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(node.sessionID == nil ? Color.secondary : Color.green)
                    
                    if let lastActivityText {
                        Text(lastActivityText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.5) : Color(nsColor: .separatorColor),
                    lineWidth: 1
                )
        )
        .contextMenu {
            Button("Duplicate", systemImage: "square.on.square") {
                onDuplicate()
            }
            
            Button("Delete", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
    }
    
    private var secondaryText: String {
        if let sessionID = node.sessionID {
            return sessionID.truncated(to: 12)
        }
        return "No session"
    }
    
    private var lastActivityText: String? {
        guard let lastActivity = node.lastActivity else {
            return nil
        }
        return RelativeDateTimeFormatter.sidebarFormatter.localizedString(for: lastActivity, relativeTo: Date())
    }
}

@MainActor
private extension RelativeDateTimeFormatter {
    static let sidebarFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
