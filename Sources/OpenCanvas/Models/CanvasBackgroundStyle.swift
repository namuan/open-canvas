import Foundation

enum CanvasBackgroundStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case dots = "Dots"
    case lines = "Lines"
    case none = "None"
    
    var id: String { rawValue }
}
