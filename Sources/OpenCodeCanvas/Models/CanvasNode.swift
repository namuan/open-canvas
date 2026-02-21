import Foundation
import SwiftUI

struct CanvasNode: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var position: CGPoint
    var sessionID: String?
    var color: NodeColor
    var isMinimized: Bool
    var size: CGSize
    var lastActivity: Date?
    
    init(
        id: UUID = UUID(),
        title: String = "New Session",
        position: CGPoint = .zero,
        sessionID: String? = nil,
        color: NodeColor = .blue,
        isMinimized: Bool = false,
        size: CGSize = CGSize(width: 320, height: 480),
        lastActivity: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.position = position
        self.sessionID = sessionID
        self.color = color
        self.isMinimized = isMinimized
        self.size = size
        self.lastActivity = lastActivity
    }
    
    static func == (lhs: CanvasNode, rhs: CanvasNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.position == rhs.position &&
        lhs.sessionID == rhs.sessionID &&
        lhs.color == rhs.color &&
        lhs.isMinimized == rhs.isMinimized &&
        lhs.size == rhs.size
    }
}
