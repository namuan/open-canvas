import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    // serverURL is always the live value from the manager — single source of truth
    var serverURL: String { serverManager.serverURL }

    var opencodeBinaryPath: String = ""
    /// Editable port string; reflects the persisted managed-server port.
    var managedServerPort: String = ""
    var nodeSpacing: CGFloat = 40
    var logLevel: LogLevel = .info
    var normalFontSize: CGFloat = 13
    var expandedFontSize: CGFloat = 16
    
    private let persistenceService = PersistenceService.shared
    private let serverManager = OpenCodeServerManager.shared
    
    func loadSettings() {
        opencodeBinaryPath = persistenceService.loadOpencodeBinaryPath()
        let port = persistenceService.loadManagedServerPort()
        managedServerPort = port > 0 ? "\(port)" : ""
        nodeSpacing = persistenceService.loadNodeSpacing()
        logLevel = persistenceService.loadLogLevel()
        normalFontSize = persistenceService.loadNormalFontSize()
        expandedFontSize = persistenceService.loadExpandedFontSize()
    }

    /// Save and apply an edited port (only valid when server is stopped).
    func applyPortChange() {
        guard let port = Int(managedServerPort), port > 0 else { return }
        persistenceService.saveManagedServerPort(port)
        // Update the live URL immediately so the read-only label refreshes.
        serverManager.serverURL = "http://localhost:\(port)"
        persistenceService.saveServerURL(serverManager.serverURL)
    }

    func saveOpencodeBinaryPath() {
        persistenceService.saveOpencodeBinaryPath(opencodeBinaryPath)
    }

    func startManagedServer() async {
        await serverManager.startManagedServer(binaryPath: opencodeBinaryPath)
        // Sync the assigned port back to the editable field
        let port = persistenceService.loadManagedServerPort()
        managedServerPort = port > 0 ? "\(port)" : ""
    }

    func stopManagedServer() {
        serverManager.stopManagedServer()
    }

    var isServerRunning: Bool { serverManager.isServerRunning || serverManager.isConnected }
    
    func saveNodeSpacing() {
        persistenceService.saveNodeSpacing(nodeSpacing)
    }
    
    func saveNormalFontSize() {
        persistenceService.saveNormalFontSize(normalFontSize)
    }

    func saveExpandedFontSize() {
        persistenceService.saveExpandedFontSize(expandedFontSize)
    }
    
    func saveLogLevel() {
        persistenceService.saveLogLevel(logLevel)
    }
    
    func reconnect() async {
        await serverManager.reconnect()
    }
    
    func revealLogsInFinder() {
        let logURL = AppLogger.shared.getLogFileURL()
        NSWorkspace.shared.activateFileViewerSelecting([logURL])
    }
    
    func purgeLogs() {
        AppLogger.shared.purgeLogs()
    }
    
    var serverVersion: String {
        serverManager.serverVersion
    }
    
    var isConnected: Bool {
        serverManager.isConnected
    }
    
    var connectionError: String? {
        serverManager.connectionError
    }
    
    var logFilePath: String {
        AppLogger.shared.getLogFileURL().path
    }
}
