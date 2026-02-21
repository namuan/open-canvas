import Foundation

enum SSEEventType: String, Codable, Sendable, CaseIterable {
    case serverConnected = "server.connected"
    case serverHeartbeat = "server.heartbeat"
    case sessionStatus = "session.status"
    case sessionIdle = "session.idle"
    case sessionCreated = "session.created"
    case sessionUpdated = "session.updated"
    case sessionDeleted = "session.deleted"
    case sessionError = "session.error"
    case sessionCompacted = "session.compacted"
    case messagePartDelta = "message.part.delta"
    case messagePartUpdated = "message.part.updated"
    case messageUpdated = "message.updated"
    case messageRemoved = "message.removed"
    case permissionAsked = "permission.asked"
    case permissionReplied = "permission.replied"
    case todoUpdated = "todo.updated"
    case fileEdited = "file.edited"
    case fileWatcherUpdated = "file.watcher.updated"
    case lspUpdated = "lsp.updated"
    case lspClientDiagnostics = "lsp.client.diagnostics"
    case vcsBranchUpdated = "vcs.branch.updated"
    case commandExecuted = "command.executed"
    case mcpToolsChanged = "mcp.tools.changed"
    case installationUpdated = "installation.updated"
    case installationUpdateAvailable = "installation.update-available"
    case projectUpdated = "project.updated"
    case ptyCreated = "pty.created"
    case ptyUpdated = "pty.updated"
    case ptyExited = "pty.exited"
    case ptyDeleted = "pty.deleted"
    case worktreeReady = "worktree.ready"
    case worktreeFailed = "worktree.failed"
    case questionAsked = "question.asked"
    case questionReplied = "question.replied"
    case questionRejected = "question.rejected"
    case globalDisposed = "global.disposed"
    case serverInstanceDisposed = "server.instance.disposed"
}

struct SSEEvent: Sendable {
    let type: SSEEventType
    let rawData: Data
    
    init(type: SSEEventType, rawData: Data) {
        self.type = type
        self.rawData = rawData
    }
    
    var sessionID: String? {
        extractString(key: "sessionID") ?? extractNestedString(path: "info", key: "id")
    }
    
    var messageID: String? {
        extractString(key: "messageID") ?? extractNestedString(path: "info", key: "id")
    }
    
    var partID: String? {
        extractString(key: "partID") ?? extractNestedString(path: "part", key: "id")
    }
    
    var status: String? {
        extractNestedString(path: "status", key: "type")
    }
    
    var delta: String? {
        extractString(key: "delta")
    }
    
    var field: String? {
        extractString(key: "field")
    }
    
    var text: String? {
        extractString(key: "text") ?? extractNestedString(path: "part", key: "text")
    }
    
    var error: String? {
        extractNestedString(path: "error/data", key: "message")
    }
    
    var role: String? {
        extractNestedString(path: "info", key: "role")
    }
    
    var toolName: String? {
        extractString(key: "tool")
    }
    
    var requestID: String? {
        extractString(key: "requestID")
    }
    
    var description: String? {
        extractString(key: "message")
    }
    
    private func extractString(key: String) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any],
              let properties = json["properties"] as? [String: Any] else { return nil }
        return properties[key] as? String
    }
    
    private func extractNestedString(path: String, key: String) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any],
              let properties = json["properties"] as? [String: Any] else { return nil }
        
        let pathComponents = path.split(separator: "/").map(String.init)
        var current: Any? = properties
        
        for component in pathComponents {
            guard let dict = current as? [String: Any] else { return nil }
            current = dict[component]
        }
        
        guard let finalDict = current as? [String: Any] else { return nil }
        return finalDict[key] as? String
    }
}

struct PermissionRequestedData: Codable, Sendable {
    public let permissionID: String
    public let toolName: String
    public let description: String
    
    public init(permissionID: String, toolName: String, description: String) {
        self.permissionID = permissionID
        self.toolName = toolName
        self.description = description
    }
}
