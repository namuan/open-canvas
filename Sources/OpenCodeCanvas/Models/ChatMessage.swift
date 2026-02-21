import Foundation

struct ChatMessage: Identifiable, Equatable, Sendable {
    let id: String
    let role: MessageRole
    var content: String
    let createdAt: Date
    var toolUse: ToolUseInfo?
    var isStreaming: Bool
    
    init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        createdAt: Date = Date(),
        toolUse: ToolUseInfo? = nil,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.toolUse = toolUse
        self.isStreaming = isStreaming
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isStreaming == rhs.isStreaming
    }
}

struct ToolUseInfo: Sendable {
    let name: String
    let status: ToolUseStatus
    let input: String?
    let output: String?
    let permissionID: String?
}

enum ToolUseStatus: String, Sendable {
    case pending
    case running
    case completed
    case error
    case permissionRequired
}
