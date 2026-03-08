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
            HStack(spacing: 0) {
                // Left column - Canvas (fills remaining space)
                CanvasView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("canvasColumn")
                
                // Right column - Integrated terminal (collapsible)
                TerminalViewWrapper()
                    .frame(maxWidth: appState.isTerminalExpanded ? .infinity : 0, maxHeight: .infinity)
                    .background(Color.black)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 1)
                    }
                    .accessibilityIdentifier("detailsColumn")
            }
            .animation(.easeInOut(duration: 0.25), value: appState.isTerminalExpanded)
            
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
        .task {
            // Test layout verification mode
            if ProcessInfo.processInfo.arguments.contains("--test-layout") {
                // Wait for layout to settle
                try? await Task.sleep(for: .seconds(1))
                
                let sizes: (canvas: CGFloat, details: CGFloat)? = await MainActor.run {
                    guard let window = NSApp.windows.first,
                          let contentView = window.contentView else {
                        return nil
                    }
                    
                    var canvasWidth: CGFloat?
                    var detailsWidth: CGFloat?
                    
                    var stack: [NSView] = [contentView]
                    while !stack.isEmpty {
                        let view = stack.removeLast()
                        if let id = view.value(forKey: "accessibilityIdentifier") as? String {
                            if id == "canvasColumn" {
                                canvasWidth = view.frame.width
                            } else if id == "detailsColumn" {
                                detailsWidth = view.frame.width
                            }
                        }
                        stack.append(contentsOf: view.subviews)
                    }
                    
                    if let cw = canvasWidth, let dw = detailsWidth {
                        return (cw, dw)
                    }
                    return nil
                }
                
                if let (canvasWidth, detailsWidth) = sizes {
                    let json = "{\"canvasWidth\": \(canvasWidth), \"detailsWidth\": \(detailsWidth)}"
                    print(json)
                } else {
                    print("{\"error\":\"views not found\"}")
                }
                
                // Allow output to flush then exit
                try? await Task.sleep(for: .seconds(1))
                exit(0)
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
        .background(.orange.opacity(0.88), in: .rect(cornerRadius: 12))
        .shadow(color: .orange.opacity(0.35), radius: 12, y: 5)
    }
}