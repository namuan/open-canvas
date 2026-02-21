import Foundation

struct NodeConnection: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let sourceNodeID: UUID
    let targetNodeID: UUID
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        sourceNodeID: UUID,
        targetNodeID: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceNodeID = sourceNodeID
        self.targetNodeID = targetNodeID
        self.createdAt = createdAt
    }
    
    static func == (lhs: NodeConnection, rhs: NodeConnection) -> Bool {
        lhs.id == rhs.id &&
        lhs.sourceNodeID == rhs.sourceNodeID &&
        lhs.targetNodeID == rhs.targetNodeID
    }
}
