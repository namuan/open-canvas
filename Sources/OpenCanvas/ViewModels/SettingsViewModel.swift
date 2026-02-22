import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    var serverURL: String = "http://localhost:4096"
    var opencodeBinaryPath: String = ""
    var nodeSpacing: CGFloat = 40
    var logLevel: LogLevel = .info
    var normalFontSize: CGFloat = 13
    var expandedFontSize: CGFloat = 16
    
    private let persistenceService = PersistenceService.shared
    private let serverManager = OpenCodeServerManager.shared
    
    func loadSettings() {
        serverURL = persistenceService.loadServerURL()
        opencodeBinaryPath = persistenceService.loadOpencodeBinaryPath()
        nodeSpacing = persistenceService.loadNodeSpacing()
        logLevel = persistenceService.loadLogLevel()
        normalFontSize = persistenceService.loadNormalFontSize()
        expandedFontSize = persistenceService.loadExpandedFontSize()
    }
    
    func saveServerURL() {
        persistenceService.saveServerURL(serverURL)
        serverManager.configure(url: serverURL)
    }

    func saveOpencodeBinaryPath() {
        persistenceService.saveOpencodeBinaryPath(opencodeBinaryPath)
    }

    func startManagedServer() async {
        await serverManager.startManagedServer(binaryPath: opencodeBinaryPath)
        // Sync the randomly assigned port URL back so the TextField reflects it
        serverURL = serverManager.serverURL
        persistenceService.saveServerURL(serverURL)
    }

    func stopManagedServer() {
        serverManager.stopManagedServer()
    }

    var isServerManaged: Bool { serverManager.isServerManaged }
    var isServerRunning: Bool { serverManager.isServerRunning }
    
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
