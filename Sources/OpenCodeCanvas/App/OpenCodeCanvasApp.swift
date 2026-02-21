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
    
    var body: some View {
        HStack(spacing: 0) {
            if appState.sidebarVisible {
                SidebarView()
            }
            
            CanvasView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .overlay(alignment: .bottom) {
            if !OpenCodeServerManager.shared.isConnected {
                offlineBanner
            }
        }
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
        .background(.orange.opacity(0.9))
        .clipShape(.rect(cornerRadius: 8))
        .padding(.bottom, 16)
    }
}
