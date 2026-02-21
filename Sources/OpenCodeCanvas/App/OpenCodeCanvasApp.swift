import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        print("Application did finish launching")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        log(.info, category: .app, "OpenCode Canvas terminating...")
    }
}

@main
struct OpenCodeCanvasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    
    init() {
        AppLogger.shared.setLogLevel(.info)
        log(.info, category: .app, "OpenCode Canvas starting...")
        print("OpenCode Canvas starting...")
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .task {
                    await appState.initialize()
                }
        }
        .defaultSize(width: 1200, height: 800)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            AppCommands(appState: appState)
            CanvasCommands(appState: appState)
            NodeCommands(appState: appState)
        }
        
        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: MainTab = .canvas
    
    private enum MainTab: Hashable {
        case canvas
        case overview
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: splitVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        } detail: {
            ZStack {
                TabView(selection: $selectedTab) {
                    CanvasView()
                        .tabItem {
                            Label("Canvas", systemImage: "square.3.layers.3d")
                        }
                        .tag(MainTab.canvas)
                    
                    overviewGrid
                        .tabItem {
                            Label("Overview", systemImage: "square.grid.2x2")
                        }
                        .tag(MainTab.overview)
                }
                
                if !OpenCodeServerManager.shared.isConnected {
                    VStack {
                        Spacer()
                        offlineBanner
                    }
                    .padding(.bottom, 16)
                }
            }
            .background(
                LinearGradient(
                    colors: [.black, Color.black.opacity(0.84), Color.cyan.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
    
    private var splitVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { appState.sidebarVisible ? .all : .detailOnly },
            set: { newValue in
                appState.setSidebarVisible(newValue != .detailOnly)
            }
        )
    }
    
    private var overviewGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 230, maximum: 320), spacing: 16)],
                spacing: 16
            ) {
                ForEach(appState.nodes) { node in
                    overviewCard(for: node)
                }
            }
            .padding(20)
        }
    }
    
    private func overviewCard(for node: CanvasNode) -> some View {
        Button {
            appState.selectedNodeID = node.id
            selectedTab = .canvas
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(node.title, systemImage: node.sessionID == nil ? "bolt.slash" : "bolt.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Circle()
                        .fill(node.color.primaryColor)
                        .frame(width: 10, height: 10)
                }
                
                Text(node.sessionID?.truncated(to: 14) ?? "No session attached")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                if let lastActivity = node.lastActivity {
                    Text(lastActivity, style: .relative)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("No recent activity")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(node.color.primaryColor.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.15), radius: 10, y: 6)
        }
        .buttonStyle(.plain)
    }
    
    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.orange)
            
            Text("OpenCode server offline — retrying...")
                .font(.system(size: 13))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.88), in: .rect(cornerRadius: 12))
        .shadow(color: .orange.opacity(0.35), radius: 12, y: 5)
    }
}
