import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    var body: some View {
        TabView {
            ServerSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Server", systemImage: "server.rack")
                }
            
            AppearanceSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            LoggingSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Logging", systemImage: "doc.text")
                }
            
            AboutSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            viewModel.loadSettings()
        }
    }
}

struct ServerSettingsTab: View {
    @Bindable var viewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section("Connection") {
                HStack {
                    Text("Server URL")
                    TextField("http://localhost:4096", text: $viewModel.serverURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(viewModel.isConnected ? "Connected" : "Disconnected")
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let error = viewModel.connectionError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                
                if !viewModel.serverVersion.isEmpty {
                    HStack {
                        Text("Server Version")
                        Spacer()
                        Text(viewModel.serverVersion)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            HStack {
                Spacer()
                Button("Reconnect") {
                    Task {
                        await viewModel.reconnect()
                    }
                }
                Button("Save") {
                    viewModel.saveServerURL()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AppearanceSettingsTab: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Form {
            Section("Canvas") {
                Picker("Background Style", selection: $viewModel.canvasBackgroundStyle) {
                    ForEach(CanvasBackgroundStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .onChange(of: viewModel.canvasBackgroundStyle) { _, _ in
                    viewModel.saveCanvasBackgroundStyle()
                }
            }
            
            Section("Nodes") {
                HStack {
                    Text("Default Color")
                    Spacer()
                    NodeColorPicker(
                        selectedColor: $viewModel.defaultNodeColor,
                        onColorSelected: { _ in
                            viewModel.saveDefaultNodeColor()
                        }
                    )
                }

                HStack {
                    Text("New Node Gap")
                    Spacer()
                    Text("\(Int(viewModel.nodeSpacing)) pt")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .trailing)
                }

                Slider(value: spacingBinding, in: 0...160, step: 4)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var spacingBinding: Binding<CGFloat> {
        Binding(
            get: { viewModel.nodeSpacing },
            set: { newValue in
                viewModel.nodeSpacing = newValue
                viewModel.saveNodeSpacing()
                appState.updateNodeSpacing(newValue)
            }
        )
    }
}

struct LoggingSettingsTab: View {
    @Bindable var viewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section("Log Settings") {
                Picker("Log Level", selection: $viewModel.logLevel) {
                    ForEach(LogLevel.allCases) { level in
                        Text("\(level.emoji) \(level.rawValue)").tag(level)
                    }
                }
                .onChange(of: viewModel.logLevel) { _, _ in
                    viewModel.saveLogLevel()
                }
            }
            
            Section("Log File") {
                HStack {
                    Text("Path")
                    Text(viewModel.logFilePath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Reveal") {
                        viewModel.revealLogsInFinder()
                    }
                }
            }
            
            Section {
                Button("Purge All Logs", role: .destructive) {
                    viewModel.purgeLogs()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AboutSettingsTab: View {
    let viewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            
            Text("OpenCanvas")
                .font(.system(size: 24, weight: .bold))
            
            Text("A Multi-Session Node Canvas for macOS")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            
            Text("Version 1.0.0")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            
            Divider()
            
            VStack(spacing: 8) {
                Text("Server Version: \(viewModel.serverVersion.isEmpty ? "Not connected" : viewModel.serverVersion)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                Text("macOS 14.0+ • Swift 5.9 • SwiftUI")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Text("Connect to a locally running OpenCode server to manage multiple AI coding sessions in parallel.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
