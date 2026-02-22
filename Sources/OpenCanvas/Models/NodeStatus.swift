import Foundation

enum NodeStatus: String, Codable, Equatable, Sendable {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case idle = "Ready"
    case running = "Running"
    case error = "Error"
    
    var displayText: String {
        rawValue
    }
}
