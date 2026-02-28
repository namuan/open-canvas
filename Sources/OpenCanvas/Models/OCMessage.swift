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
    let model: OCPromptModel?
    
    init(content: String, model: String? = nil) {
        parts = [OCPromptPart(type: "text", text: content)]
        self.model = OCPromptModel(modelString: model)
    }
}

struct OCPromptPart: Codable, Sendable {
    let type: String
    let text: String
}

struct OCPromptModel: Codable, Sendable {
    let providerID: String
    let modelID: String
    
    init?(modelString: String?) {
        guard let modelString, !modelString.isEmpty else { return nil }
        
        let parts = modelString.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        
        let provider = String(parts[0])
        let model = String(parts[1])
        guard !provider.isEmpty, !model.isEmpty else { return nil }
        
        providerID = provider
        modelID = model
    }
    
    var displayName: String {
        "\(providerID)/\(modelID)"
    }
}

struct OCModel: Codable, Sendable, Identifiable {
    let id: String
    let providerID: String
    let name: String
    let family: String?
    
    var displayName: String {
        name.isEmpty ? id : name
    }
    
    var fullID: String {
        "\(providerID)/\(id)"
    }
}

struct OCProvider: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let source: String
    let models: [String: OCModel]
}

struct OCProvidersResponse: Codable, Sendable {
    let providers: [OCProvider]
    let defaultModel: [String: String]
    
    enum CodingKeys: String, CodingKey {
        case providers
        case defaultModel = "default"
    }
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
