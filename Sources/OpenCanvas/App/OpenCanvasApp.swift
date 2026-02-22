import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        print("Application did finish launching")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        log(.info, category: .app, "OpenCanvas terminating...")
    }
}

@main
struct OpenCanvasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    
    init() {
        AppLogger.shared.setLogLevel(.info)
        log(.info, category: .app, "OpenCanvas starting...")
        print("OpenCanvas starting...")
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
        ZStack {
            CanvasView()
            
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
