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
        .frame(width: 540, height: 520)
        .onHover { hovering in
            appState.isHoveringOverSettings = hovering
        }
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
                TextField("http://localhost:4097", text: $viewModel.serverURL)
                    .textFieldStyle(.roundedBorder)
                
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

            Section("Server Management") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.isServerManaged ? "Managed by OpenCanvas" : "External (unmanaged)")
                            .font(.subheadline)
                        Text(viewModel.isServerManaged ? "opencode serve" : "Start OpenCanvas-managed server below")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospaced()
                    }
                    Spacer()
                    if viewModel.isServerManaged && viewModel.isServerRunning {
                        Button("Stop Server") {
                            viewModel.stopManagedServer()
                        }
                        .foregroundStyle(.red)
                    } else {
                        Button("Start Server") {
                            Task { await viewModel.startManagedServer() }
                        }
                        .disabled(viewModel.isServerManaged)
                    }
                }

                HStack {
                    Text("Binary Path")
                        .foregroundStyle(.secondary)
                    TextField("Auto-detect (e.g. /opt/homebrew/bin/opencode)", text: $viewModel.opencodeBinaryPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .onChange(of: viewModel.opencodeBinaryPath) { _, _ in
                            viewModel.saveOpencodeBinaryPath()
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
            Section("Nodes") {
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

            Section("Session Node Fonts") {
                HStack {
                    Text("Normal Font Size")
                    Spacer()
                    Text("\(Int(viewModel.normalFontSize)) pt")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)
                }

                Slider(value: normalFontSizeBinding, in: 10...24, step: 1)

                HStack {
                    Text("Fullscreen Font Size")
                    Spacer()
                    Text("\(Int(viewModel.expandedFontSize)) pt")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)
                }

                Slider(value: expandedFontSizeBinding, in: 12...32, step: 1)
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

    private var normalFontSizeBinding: Binding<CGFloat> {
        Binding(
            get: { viewModel.normalFontSize },
            set: { newValue in
                viewModel.normalFontSize = newValue
                viewModel.saveNormalFontSize()
                appState.updateNormalFontSize(newValue)
            }
        )
    }

    private var expandedFontSizeBinding: Binding<CGFloat> {
        Binding(
            get: { viewModel.expandedFontSize },
            set: { newValue in
                viewModel.expandedFontSize = newValue
                viewModel.saveExpandedFontSize()
                appState.updateExpandedFontSize(newValue)
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
