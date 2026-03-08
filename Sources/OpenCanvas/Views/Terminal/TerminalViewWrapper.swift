import SwiftTerm
import SwiftUI

struct TerminalViewWrapper: NSViewRepresentable {
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminalView.processDelegate = context.coordinator
        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Start the process only once when the view is first created
        if nsView.process == nil || !nsView.process.running {
            nsView.startProcess(executable: "/bin/zsh", args: ["-l"])
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            print("Terminal resized to \(newCols)x\(newRows)")
        }

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            print("Terminal title: \(title)")
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            if let dir = directory {
                print("Current directory: \(dir)")
            }
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            if let code = exitCode {
                print("Process terminated with exit code: \(code)")
            } else {
                print("Process terminated with error")
            }
        }
    }
}

