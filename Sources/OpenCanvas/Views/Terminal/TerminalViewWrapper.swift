import SwiftTerm
import SwiftUI

struct TerminalViewWrapper: NSViewRepresentable {
    @Environment(AppState.self) private var appState

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminalView.processDelegate = context.coordinator
        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Terminate session if requested
        if appState.shouldTerminateTerminalSession {
            if nsView.process?.running == true {
                nsView.terminate()
            }
            appState.shouldTerminateTerminalSession = false
            appState.pendingSessionCommand = nil // Clear any pending command to avoid execution after termination
        }

        // Start the process only once
        if nsView.process == nil || !nsView.process.running {
            nsView.startProcess(executable: "/bin/zsh", args: ["-l"])
            context.coordinator.isRunning = true
        }

        if let command = appState.pendingSessionCommand {
            appState.pendingSessionCommand = nil

            var fullCommand = ""
            let directory = command.directory
            let sessionID = command.sessionID

            if !directory.isEmpty {
                let escapedDir = directory.replacingOccurrences(of: "\"", with: "\\\"")
                fullCommand = "cd \"\(escapedDir)\"\r\n"
            }
            fullCommand.append("opencode -s \(sessionID)\r\n")

            let bytes = Array(fullCommand.utf8)
            nsView.process?.send(data: bytes[...])
            log(.debug, category: .ui, "Executed command in terminal: \(fullCommand)")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleNSView(_ nsView: LocalProcessTerminalView, coordinator: Coordinator) {
        if nsView.process?.running == true {
            nsView.terminate()
            coordinator.isRunning = false
        }
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var isRunning = false

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            log(.debug, category: .ui, "Terminal resized to \(newCols)x\(newRows)")
        }

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            log(.debug, category: .ui, "Terminal title changed: \(title)")
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            if let dir = directory {
                log(.debug, category: .ui, "Terminal current directory: \(dir)")
            }
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            if let code = exitCode {
                log(.info, category: .ui, "Terminal process terminated with exit code: \(code)")
            } else {
                log(.warning, category: .ui, "Terminal process terminated with error")
            }
            isRunning = false
        }
    }
}
