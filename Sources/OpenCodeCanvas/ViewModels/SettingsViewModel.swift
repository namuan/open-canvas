import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    var serverURL: String = "http://localhost:4096"
    var canvasBackgroundStyle: CanvasBackgroundStyle = .dots
    var defaultNodeColor: NodeColor = .blue
    var logLevel: LogLevel = .info
    
    private let persistenceService = PersistenceService.shared
    private let serverManager = OpenCodeServerManager.shared
    
    func loadSettings() {
        serverURL = persistenceService.loadServerURL()
        canvasBackgroundStyle = persistenceService.loadCanvasBackgroundStyle()
        defaultNodeColor = persistenceService.loadDefaultNodeColor()
        logLevel = persistenceService.loadLogLevel()
    }
    
    func saveServerURL() {
        persistenceService.saveServerURL(serverURL)
        serverManager.configure(url: serverURL)
    }
    
    func saveCanvasBackgroundStyle() {
        persistenceService.saveCanvasBackgroundStyle(canvasBackgroundStyle)
    }
    
    func saveDefaultNodeColor() {
        persistenceService.saveDefaultNodeColor(defaultNodeColor)
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
