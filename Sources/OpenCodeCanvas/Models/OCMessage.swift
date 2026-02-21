import Foundation

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

struct OCMessage: Identifiable, Codable, Sendable {
    let info: OCMessageInfo
    let parts: [OCMessagePart]
    
    var id: String { info.id }
    var role: MessageRole { info.role }
    var content: String {
        parts.compactMap { part in
            if part.type == "text", let text = part.text {
                return text
            }
            return nil
        }.joined(separator: "\n")
    }
}

struct OCMessageInfo: Codable, Sendable {
    let id: String
    let role: MessageRole
    let time: OCMessageTime?
    let modelID: String?
    let sessionID: String?
    
    enum CodingKeys: String, CodingKey {
        case id, role, time
        case modelID
        case sessionID
    }
}

struct OCMessageTime: Codable, Sendable {
    let created: Date?
    let updated: Date?
    let completed: Date?
}

struct OCMessagePart: Codable, Sendable {
    let id: String
    let type: String
    let text: String?
    let toolUse: OCToolUse?
    
    enum CodingKeys: String, CodingKey {
        case id, type, text
        case toolUse = "tool_use"
    }
}

struct OCToolUse: Codable, Sendable {
    let name: String?
    let status: String?
    let input: String?
    let output: String?
    let id: String?
    let permissionID: String?
    
    enum CodingKeys: String, CodingKey {
        case name, status, input, output, id
        case permissionID
    }
}

struct OCPromptRequest: Codable, Sendable {
    let parts: [OCPromptPart]
    
    init(content: String, model: String? = nil) {
        self.parts = [OCPromptPart(type: "text", text: content)]
    }
}

struct OCPromptPart: Codable, Sendable {
    let type: String
    let text: String
}

struct OCForkRequest: Codable, Sendable {
    let messageID: String?
    
    init(messageID: String) {
        self.messageID = messageID
    }
}

struct OCSessionResponse: Codable, Sendable {
    let id: String
    let title: String?
}
