import Foundation
import Combine

struct ServerHealthResponse: Codable, Sendable {
    let healthy: Bool
    let version: String
}

enum OpenCodeError: Error, LocalizedError, Sendable {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, String?)
    case notConnected
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        case .notConnected:
            return "Not connected to OpenCode server"
        }
    }
}

@MainActor
@Observable
final class OpenCodeServerManager {
    static let shared = OpenCodeServerManager()
    
    var serverURL: String = "http://localhost:4097"
    var isConnected: Bool = false
    var serverVersion: String = ""
    var connectionError: String?
    
    private(set) var eventSubject = PassthroughSubject<SSEEvent, Never>()
    var eventPublisher: AnyPublisher<SSEEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    private var serverProcess: Process?
    var isServerRunning: Bool { serverProcess?.isRunning ?? false }

    private var sseTask: Task<Void, Never>?
    private var healthCheckTask: Task<Void, Never>?
    private var retryCount: Int = 0
    private let maxRetries: Int = 5
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
    private let jsonEncoder = JSONEncoder()
    
    private var baseURL: URL? {
        URL(string: serverURL)
    }
    
    private init() {}
    
    nonisolated func configure(url: String) {
        Task { @MainActor in
            self.serverURL = url
            await reconnect()
        }
    }
    
    func connect() async {
        log(.info, category: .network, "Connecting to OpenCode server at \(serverURL)")
        
        await checkHealth()
        await startSSEStream()
        startHealthCheckPolling()
    }
    
    func reconnect() async {
        disconnect()
        await connect()
    }
    
    func disconnect() {
        sseTask?.cancel()
        sseTask = nil
        healthCheckTask?.cancel()
        healthCheckTask = nil
        isConnected = false
        retryCount = 0
    }

    // MARK: - Managed Server Lifecycle

    func startManagedServer(binaryPath: String) async {
        stopManagedServer()

        let resolvedPath: String
        if binaryPath.isEmpty {
            guard let found = await findOpencodeBinary() else {
                connectionError = "Cannot find 'opencode' binary. Set the path in Settings > Server."
                log(.error, category: .network, "Failed to find opencode binary")
                return
            }
            resolvedPath = found
        } else {
            resolvedPath = binaryPath
        }

        let persistence = PersistenceService.shared
        var port = persistence.loadManagedServerPort()
        if port == 0 {
            port = Int.random(in: 49152...65535)
            persistence.saveManagedServerPort(port)
            log(.info, category: .network, "Assigned new managed server port: \(port)")
        } else {
            log(.info, category: .network, "Reusing persisted managed server port: \(port)")
        }
        let url = "http://localhost:\(port)"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolvedPath)
        process.arguments = ["serve", "--port", "\(port)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        process.terminationHandler = { [weak self] p in
            Task { @MainActor [weak self] in
                self?.serverProcess = nil
                log(.info, category: .network, "opencode server process terminated (status \(p.terminationStatus))")
            }
        }

        do {
            try process.run()
            serverProcess = process
            serverURL = url
            persistence.saveManagedServerPID(process.processIdentifier)
            log(.info, category: .network, "Started managed opencode server: \(resolvedPath) serve --port \(port) (PID \(process.processIdentifier))")
            // Give the server a moment to start before connecting
            try? await Task.sleep(for: .seconds(1.5))
            await reconnect()
        } catch {
            connectionError = "Failed to start server: \(error.localizedDescription)"
            log(.error, category: .network, "Failed to launch opencode process: \(error)")
        }
    }

    func stopManagedServer() {
        if let proc = serverProcess, proc.isRunning {
            proc.terminate()
            log(.info, category: .network, "Terminated managed opencode server process")
        }
        serverProcess = nil
        PersistenceService.shared.clearManagedServerPID()
        disconnect()
    }

    /// Called at startup to detect whether the previously managed server process is still alive.
    /// If so, restores the server URL without re-launching and returns true.
    @discardableResult
    func detectRunningManagedServer() -> Bool {
        let persistence = PersistenceService.shared
        let pid = persistence.loadManagedServerPID()
        guard pid > 0 else { return false }

        // kill(pid, 0) returns 0 if the process exists and we can signal it.
        let alive = Darwin.kill(pid, 0) == 0
        if alive {
            let port = persistence.loadManagedServerPort()
            if port > 0 {
                serverURL = "http://localhost:\(port)"
            }
            log(.info, category: .network, "Detected previously managed opencode server still running (PID \(pid), port \(port))")
        } else {
            persistence.clearManagedServerPID()
            log(.info, category: .network, "Previously managed opencode server (PID \(pid)) is no longer running")
        }
        return alive
    }

    private func findOpencodeBinary() async -> String? {
        let commonPaths = [
            "/opt/homebrew/bin/opencode",
            "/usr/local/bin/opencode",
            "/usr/bin/opencode",
        ]
        for path in commonPaths where FileManager.default.fileExists(atPath: path) {
            log(.info, category: .network, "Found opencode binary at: \(path)")
            return path
        }

        // Fall back to resolving via login shell
        return await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", "which opencode"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let result = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return result.isEmpty ? nil : result
            } catch {
                return nil
            }
        }.value
    }

    private func checkHealth() async {
        guard let url = baseURL?.appendingPathComponent("global/health") else {
            connectionError = "Invalid server URL"
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 5
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenCodeError.serverError(0, "Invalid response")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw OpenCodeError.serverError(httpResponse.statusCode, nil)
            }
            
            let healthResponse = try jsonDecoder.decode(ServerHealthResponse.self, from: data)
            isConnected = true
            serverVersion = healthResponse.version
            connectionError = nil
            retryCount = 0
        } catch {
            isConnected = false
            if retryCount == 0 {
                connectionError = "Server not available at \(serverURL)"
            }
            retryCount += 1
        }
    }
    
    private func startHealthCheckPolling() {
        healthCheckTask = Task { [weak self] in
            var failureCount = 0
            while !Task.isCancelled {
                let interval: TimeInterval = failureCount >= 5 ? 10 : 3
                try? await Task.sleep(for: .seconds(interval))
                
                if Task.isCancelled { break }
                
                await self?.checkHealth()
                
                if self?.isConnected == true {
                    failureCount = 0
                } else {
                    failureCount += 1
                }
            }
        }
    }
    
    private func startSSEStream() async {
        sseTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.connectSSE()
                if !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        }
    }
    
    private func connectSSE() async {
        guard let url = baseURL?.appendingPathComponent("global/event") else {
            log(.error, category: .sse, "Invalid SSE URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 0
        
        log(.info, category: .sse, "Connecting to SSE stream at \(url.absoluteString)")
        
        do {
            let (bytes, _) = try await URLSession.shared.bytes(for: request)
            
            log(.info, category: .sse, "SSE stream connected, waiting for events...")
            
            for try await line in bytes.lines {
                if Task.isCancelled { break }
                
                // OpenCode server sends each event as a single "data:" line
                // No blank lines between events, no "event:" prefix
                if line.hasPrefix("data:") {
                    let data = String(line.dropFirst(5)).trimmed
                    await processSSEEvent(data: data)
                }
            }
            
            log(.warning, category: .sse, "SSE stream ended (for loop completed)")
        } catch {
            if !Task.isCancelled {
                log(.error, category: .sse, "SSE stream error: \(error.localizedDescription)")
                await MainActor.run {
                    retryCount += 1
                    if retryCount >= 3 {
                        isConnected = false
                        connectionError = "SSE connection lost"
                    }
                }
            }
        }
    }
    
    private func processSSEEvent(data: String) async {
        guard let jsonData = data.data(using: .utf8) else {
            log(.error, category: .sse, "Failed to convert SSE data to UTF-8")
            return
        }

        // /global/event wraps each event: {"directory":"...","payload":{...event...}}
        // Extract the inner payload if present, otherwise treat as a bare event.
        guard let outerJson = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            log(.error, category: .sse, "Failed to parse SSE JSON: \(data)")
            return
        }

        let eventJson: [String: Any]
        if let payload = outerJson["payload"] as? [String: Any] {
            eventJson = payload
        } else {
            eventJson = outerJson
        }

        guard let _ = try? JSONSerialization.data(withJSONObject: eventJson),
              let typeString = eventJson["type"] as? String,
              let eventType = SSEEventType(rawValue: typeString) else {
            log(.error, category: .sse, "Failed to parse SSE event type")
            log(.error, category: .sse, "Raw JSON that failed: \(data)")
            return
        }


        let event = SSEEvent(type: eventType, rawData: jsonData, jsonObject: eventJson)
        
        switch eventType {
        case .messagePartDelta, .messagePartUpdated:
            log(.debug, category: .sse, "SSE \(eventType.rawValue) sessionID=\(event.sessionID ?? "-")")
        case .serverHeartbeat:
            break
        default:
            let sessionPart = event.sessionID.map { " sessionID=\($0)" } ?? ""
            log(.info, category: .sse, "SSE \(eventType.rawValue)\(sessionPart)")
        }
        
        if event.type == .serverConnected {
            isConnected = true
            retryCount = 0
            log(.info, category: .sse, "Server connected event processed")
        }
        
        eventSubject.send(event)
    }
    
    func listSessions() async throws -> [OCSession] {
        guard let url = baseURL?.appendingPathComponent("session") else {
            throw OpenCodeError.invalidURL
        }
        
        let sessions: [OCSession] = try await get(url)
        log(.debug, category: .network, "Listed \(sessions.count) sessions")
        return sessions
    }
    
    func getProviders() async throws -> OCProvidersResponse {
        guard let url = baseURL?.appendingPathComponent("config/providers") else {
            throw OpenCodeError.invalidURL
        }
        
        let providers: OCProvidersResponse = try await get(url)
        log(.debug, category: .network, "Fetched \(providers.providers.count) providers")
        return providers
    }
    
    func getSession(id: String) async throws -> OCSession {
        guard let url = baseURL?.appendingPathComponent("session/\(id)") else {
            throw OpenCodeError.invalidURL
        }
        
        let session: OCSession = try await get(url)
        log(.debug, category: .network, "Got session: \(id)")
        return session
    }
    
    func createSession(model: String? = nil) async throws -> OCSession {
        guard let url = baseURL?.appendingPathComponent("session") else {
            throw OpenCodeError.invalidURL
        }
        
        let request = OCSessionCreateRequest(title: nil)
        let session: OCSession = try await post(url, body: request)
        log(.info, category: .session, "Created session: \(session.id)")
        return session
    }
    
    func deleteSession(id: String) async throws {
        guard let url = baseURL?.appendingPathComponent("session/\(id)") else {
            throw OpenCodeError.invalidURL
        }
        
        try await delete(url)
        log(.info, category: .session, "Deleted session: \(id)")
    }
    
    func renameSession(id: String, title: String) async throws {
        guard let url = baseURL?.appendingPathComponent("session/\(id)") else {
            throw OpenCodeError.invalidURL
        }
        
        let request = OCSessionPatchRequest(title: title)
        try await patch(url, body: request)
        log(.info, category: .session, "Renamed session \(id) to: \(title)")
    }
    
    func sendPrompt(sessionID: String, content: String, model: String? = nil, directory: String? = nil) async throws {
        guard let baseURL,
              var components = URLComponents(url: baseURL.appendingPathComponent("session/\(sessionID)/prompt_async"), resolvingAgainstBaseURL: false) else {
            throw OpenCodeError.invalidURL
        }
        
        if let directory {
            components.queryItems = [URLQueryItem(name: "directory", value: directory)]
        }
        
        guard let url = components.url else {
            throw OpenCodeError.invalidURL
        }
        
        let request = OCPromptRequest(content: content, model: model)
        if let promptBodyData = try? jsonEncoder.encode(request),
           let promptBody = responseBodyString(from: promptBodyData) {
            log(.info, category: .network, "Prompt request payload for session \(sessionID): \(promptBody)")
        }
        
        try await postNoResponse(url, body: request)
        log(.info, category: .session, "Sent prompt to session \(sessionID): \(content.truncated(to: 50))")
    }
    
    func abortSession(id: String) async throws {
        guard let url = baseURL?.appendingPathComponent("session/\(id)/abort") else {
            throw OpenCodeError.invalidURL
        }
        
        try await postNoResponse(url, body: EmptyBody())
        log(.info, category: .session, "Aborted session: \(id)")
    }
    
    func forkSession(id: String, messageID: String) async throws -> String {
        guard let url = baseURL?.appendingPathComponent("session/\(id)/fork") else {
            throw OpenCodeError.invalidURL
        }
        
        let request = OCForkRequest(messageID: messageID)
        let session: OCSession = try await post(url, body: request)
        log(.info, category: .session, "Forked session \(id) to \(session.id)")
        return session.id
    }
    
    func getMessages(sessionID: String) async throws -> [OCMessage] {
        guard let url = baseURL?.appendingPathComponent("session/\(sessionID)/message") else {
            throw OpenCodeError.invalidURL
        }
        
        let messages: [OCMessage] = try await get(url)
        log(.debug, category: .network, "Fetched \(messages.count) messages for session \(sessionID)")
        return messages
    }
    
    func respondToPermission(sessionID: String, permissionID: String, approved: Bool) async throws {
        guard let url = baseURL?.appendingPathComponent("session/\(sessionID)/permissions/\(permissionID)") else {
            throw OpenCodeError.invalidURL
        }
        
        let request = PermissionResponse(approved: approved)
        try await postNoResponse(url, body: request)
        log(.info, category: .session, "Responded to permission \(permissionID): \(approved ? "approved" : "denied")")
    }
    
    private func get<T: Decodable>(_ url: URL) async throws -> T {
        log(.debug, category: .network, "GET \(url.path)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        logRequest(request, bodyData: nil)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            logResponse(response, data: data, for: request)
            try validateResponse(response, data: data, for: request)
            return try jsonDecoder.decode(T.self, from: data)
        } catch let error as OpenCodeError {
            throw error
        } catch {
            throw OpenCodeError.networkError(error)
        }
    }
    
    private func post<T: Encodable, R: Decodable>(_ url: URL, body: T) async throws -> R {
        log(.debug, category: .network, "POST \(url.path)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let bodyData = try jsonEncoder.encode(body)
        request.httpBody = bodyData
        logRequest(request, bodyData: bodyData)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            logResponse(response, data: data, for: request)
            try validateResponse(response, data: data, for: request)
            return try jsonDecoder.decode(R.self, from: data)
        } catch let error as OpenCodeError {
            throw error
        } catch {
            throw OpenCodeError.networkError(error)
        }
    }
    
    private func postNoResponse<T: Encodable>(_ url: URL, body: T) async throws {
        log(.debug, category: .network, "POST \(url.path) (no response expected)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let bodyData = try jsonEncoder.encode(body)
        request.httpBody = bodyData
        logRequest(request, bodyData: bodyData)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            logResponse(response, data: data, for: request)
            try validateResponse(response, data: data, for: request)
        } catch let error as OpenCodeError {
            throw error
        } catch {
            throw OpenCodeError.networkError(error)
        }
    }
    
    private func patch<T: Encodable>(_ url: URL, body: T) async throws {
        log(.debug, category: .network, "PATCH \(url.path)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let bodyData = try jsonEncoder.encode(body)
        request.httpBody = bodyData
        logRequest(request, bodyData: bodyData)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            logResponse(response, data: data, for: request)
            try validateResponse(response, data: data, for: request)
        } catch let error as OpenCodeError {
            throw error
        } catch {
            throw OpenCodeError.networkError(error)
        }
    }
    
    private func delete(_ url: URL) async throws {
        log(.debug, category: .network, "DELETE \(url.path)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        logRequest(request, bodyData: nil)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            logResponse(response, data: data, for: request)
            try validateResponse(response, data: data, for: request)
        } catch let error as OpenCodeError {
            throw error
        } catch {
            throw OpenCodeError.networkError(error)
        }
    }
    
    private func validateResponse(_ response: URLResponse, data: Data?, for request: URLRequest) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenCodeError.serverError(0, "Invalid response")
        }
        
        let responseBody = responseBodyString(from: data) ?? "<empty>"
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 400...499:
            throw OpenCodeError.serverError(
                httpResponse.statusCode,
                "Client error for \(request.httpMethod ?? "REQUEST") \(request.url?.path ?? ""): \(responseBody)"
            )
        case 500...599:
            throw OpenCodeError.serverError(
                httpResponse.statusCode,
                "Server error for \(request.httpMethod ?? "REQUEST") \(request.url?.path ?? ""): \(responseBody)"
            )
        default:
            throw OpenCodeError.serverError(
                httpResponse.statusCode,
                "Unknown error for \(request.httpMethod ?? "REQUEST") \(request.url?.path ?? ""): \(responseBody)"
            )
        }
    }
    
    private func logRequest(_ request: URLRequest, bodyData: Data?) {
        let shouldPromoteLogLevel = (request.url?.path.contains("/prompt_async") ?? false)
        let logLevel: LogLevel = shouldPromoteLogLevel ? .info : .debug
        
        var details: [String] = []
        details.append("HTTP Request")
        details.append("method=\(request.httpMethod ?? "UNKNOWN")")
        details.append("url=\(request.url?.absoluteString ?? "<nil>")")
        
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            details.append("headers=\(headers)")
        }
        
        if let bodyData {
            details.append("body=\(responseBodyString(from: bodyData) ?? "<binary>")")
        } else {
            details.append("body=<empty>")
        }
        
        log(logLevel, category: .network, details.joined(separator: " | "))
    }
    
    private func logResponse(_ response: URLResponse, data: Data?, for request: URLRequest) {
        let isPromptRequest = request.url?.path.contains("/prompt_async") ?? false
        
        guard let httpResponse = response as? HTTPURLResponse else {
            let level: LogLevel = isPromptRequest ? .info : .debug
            log(level, category: .network, "HTTP Response | method=\(request.httpMethod ?? "UNKNOWN") | url=\(request.url?.absoluteString ?? "<nil>") | invalid response type")
            return
        }
        
        let logLevel: LogLevel = (isPromptRequest || !(200...299).contains(httpResponse.statusCode)) ? .info : .debug
        
        var details: [String] = []
        details.append("HTTP Response")
        details.append("method=\(request.httpMethod ?? "UNKNOWN")")
        details.append("url=\(request.url?.absoluteString ?? "<nil>")")
        details.append("status=\(httpResponse.statusCode)")
        details.append("headers=\(httpResponse.allHeaderFields)")
        details.append("body=\(responseBodyString(from: data) ?? "<empty>")")
        
        log(logLevel, category: .network, details.joined(separator: " | "))
    }
    
    private func responseBodyString(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }
        return String(data: data, encoding: .utf8)
    }
}

private struct EmptyBody: Encodable, Sendable {}

private struct PermissionResponse: Encodable, Sendable {
    let approved: Bool
}
