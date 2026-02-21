import SwiftUI

struct AppCommands: Commands {
    @Bindable var appState: AppState
    
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About OpenCode Canvas") {
                NSApplication.shared.orderFrontStandardAboutPanel(
                    options: [
                        .applicationName: "OpenCode Canvas",
                        .applicationVersion: "1.0.0",
                        .version: "1"
                    ]
                )
            }
        }
        
        CommandGroup(replacing: .newItem) {
            Button("New Node") {
                appState.addNode()
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        
        CommandGroup(after: .toolbar) {
            Button("Toggle Sidebar") {
                appState.toggleSidebar()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }
    }
}

struct CanvasCommands: Commands {
    @Bindable var appState: AppState
    
    var body: some Commands {
        CommandMenu("Canvas") {
            Button("Add Node") {
                appState.addNode()
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Button("Auto Layout") {
                appState.autoLayout()
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Zoom In") {
                appState.zoomIn()
            }
            .keyboardShortcut("+", modifiers: .command)
            
            Button("Zoom Out") {
                appState.zoomOut()
            }
            .keyboardShortcut("-", modifiers: .command)
            
            Button("Reset View") {
                appState.resetView()
            }
            .keyboardShortcut("0", modifiers: .command)
            
            Divider()
            
            Button("Clear Canvas") {
                appState.clearCanvas()
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
        }
    }
}

struct NodeCommands: Commands {
    @Bindable var appState: AppState
    
    var body: some Commands {
        CommandMenu("Node") {
            Button("Close Selected Node") {
                if let nodeID = appState.selectedNodeID {
                    Task {
                        await appState.removeNode(id: nodeID)
                    }
                }
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(appState.selectedNodeID == nil)
            
            Button("Duplicate Selected Node") {
                if let nodeID = appState.selectedNodeID {
                    appState.duplicateNode(id: nodeID)
                }
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(appState.selectedNodeID == nil)
            
            Divider()
            
            Button("Abort Running Session") {
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .disabled(appState.selectedNodeID == nil)
            
            Button("Fork Selected Session") {
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(appState.selectedNodeID == nil)
            
            Divider()
            
            Button("Select Next Node") {
                appState.selectNextNode()
            }
            .keyboardShortcut(.tab, modifiers: [])
        }
    }
}
