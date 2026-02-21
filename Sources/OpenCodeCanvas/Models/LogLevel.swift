import Foundation

enum LogLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case debug = "Debug"
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    
    var id: String { rawValue }
    
    var emoji: String {
        switch self {
        case .debug: "🔍"
        case .info: "ℹ️"
        case .warning: "⚠️"
        case .error: "❌"
        }
    }
}
