import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    var serverURL: String = "http://localhost:4096"
    var canvasBackgroundStyle: CanvasBackgroundStyle = .dots
    var defaultNodeColor: NodeColor = .blue
    var nodeSpacing: CGFloat = 40
    var logLevel: LogLevel = .info
    var normalFontSize: CGFloat = 13
    var expandedFontSize: CGFloat = 16
    
    private let persistenceService = PersistenceService.shared
    private let serverManager = OpenCodeServerManager.shared
    
    func loadSettings() {
        serverURL = persistenceService.loadServerURL()
        canvasBackgroundStyle = persistenceService.loadCanvasBackgroundStyle()
        defaultNodeColor = persistenceService.loadDefaultNodeColor()
        nodeSpacing = persistenceService.loadNodeSpacing()
        logLevel = persistenceService.loadLogLevel()
        normalFontSize = persistenceService.loadNormalFontSize()
        expandedFontSize = persistenceService.loadExpandedFontSize()
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
