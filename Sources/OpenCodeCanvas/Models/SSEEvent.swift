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
    let sessionID: String?
    let messageID: String?
    let partID: String?
    let status: String?
    let delta: String?
    let field: String?
    let text: String?
    let error: String?
    let role: String?
    let toolName: String?
    let requestID: String?
    let description: String?
    
    init(type: SSEEventType, rawData: Data, jsonObject: [String: Any]? = nil) {
        self.type = type
        self.rawData = rawData
        
        let properties: [String: Any]? = {
            if let jsonObject, let properties = jsonObject["properties"] as? [String: Any] {
                return properties
            }
            guard let parsed = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any],
                  let properties = parsed["properties"] as? [String: Any] else {
                return nil
            }
            return properties
        }()

        self.sessionID = Self.extractString(in: properties, key: "sessionID")
            ?? Self.extractNestedString(in: properties, path: "info", key: "id")
        self.messageID = Self.extractString(in: properties, key: "messageID")
            ?? Self.extractNestedString(in: properties, path: "info", key: "id")
        self.partID = Self.extractString(in: properties, key: "partID")
            ?? Self.extractNestedString(in: properties, path: "part", key: "id")
        self.status = Self.extractNestedString(in: properties, path: "status", key: "type")
        self.delta = Self.extractString(in: properties, key: "delta")
        self.field = Self.extractString(in: properties, key: "field")
        self.text = Self.extractString(in: properties, key: "text")
            ?? Self.extractNestedString(in: properties, path: "part", key: "text")
        self.error = Self.extractNestedString(in: properties, path: "error/data", key: "message")
        self.role = Self.extractNestedString(in: properties, path: "info", key: "role")
        self.toolName = Self.extractString(in: properties, key: "tool")
        self.requestID = Self.extractString(in: properties, key: "requestID")
        self.description = Self.extractString(in: properties, key: "message")
    }

    private static func extractString(in properties: [String: Any]?, key: String) -> String? {
        properties?[key] as? String
    }

    private static func extractNestedString(in properties: [String: Any]?, path: String, key: String) -> String? {
        guard let properties else { return nil }

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
