import Foundation
import SwiftUI
import Combine

@MainActor
@Observable
final class SessionNodeViewModel {
    private static let defaultModelID = "github-copilot/gpt-4o"
    
    let nodeID: UUID
    var sessionID: String?
    var status: NodeStatus = .disconnected
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var errorMessage: String?
    var streamingMessageID: String?
    var pendingPermission: PermissionRequestedData?
    var selectedModel: String? = SessionNodeViewModel.defaultModelID
    
    private let serverManager = OpenCodeServerManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(nodeID: UUID) {
        self.nodeID = nodeID
        
        log(.debug, category: .session, "SessionNodeViewModel init for node \(nodeID)")
        
        serverManager.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                log(.debug, category: .session, "ViewModel received event via publisher: \(event.type)")
                Task { @MainActor [weak self] in
                    self?.handleSSEEvent(event)
                }
            }
            .store(in: &cancellables)
        
        log(.debug, category: .session, "Subscribed to SSE event publisher")
    }
    
    func configure(with sessionID: String?) {
        self.sessionID = sessionID
        
        if sessionID != nil {
            status = .idle
            Task {
                await loadMessages()
            }
        } else {
            status = .disconnected
            messages.removeAll()
        }
    }
    
    func createSession() async {
        status = .connecting
        errorMessage = nil
        
        do {
            let session = try await serverManager.createSession(model: selectedModel)
            sessionID = session.id
            status = .idle
            
            log(.info, category: .session, "Created session \(session.id) for node \(nodeID)")
        } catch {
            status = .error
            errorMessage = error.localizedDescription
            log(.error, category: .session, "Failed to create session: \(error.localizedDescription)")
        }
    }
    
    func deleteSession() async {
        guard let sessionID = sessionID else { return }
        
        do {
            try await serverManager.deleteSession(id: sessionID)
            self.sessionID = nil
            status = .disconnected
            messages.removeAll()
            
            log(.info, category: .session, "Deleted session \(sessionID)")
        } catch {
            errorMessage = error.localizedDescription
            log(.error, category: .session, "Failed to delete session: \(error.localizedDescription)")
        }
    }
    
    func sendMessage() async {
        guard let sessionID = sessionID,
              !inputText.trimmed.isEmpty else { return }
        
        let content = inputText.trimmed
        inputText = ""
        errorMessage = nil
        
        let userMessage = ChatMessage(
            role: .user,
            content: content,
            createdAt: Date()
        )
        messages.append(userMessage)
        
        status = .running
        
        let assistantMessage = ChatMessage(
            role: .assistant,
            content: "",
            createdAt: Date(),
            isStreaming: true
        )
        messages.append(assistantMessage)
        streamingMessageID = assistantMessage.id
        
        do {
            try await serverManager.sendPrompt(sessionID: sessionID, content: content, model: selectedModel)
            log(.info, category: .session, "Sent prompt to session \(sessionID)")
        } catch {
            status = .error
            errorMessage = error.localizedDescription
            messages.removeAll { $0.id == assistantMessage.id }
            streamingMessageID = nil
            log(.error, category: .session, "Failed to send prompt: \(error.localizedDescription)")
        }
    }
    
    func abortGeneration() async {
        guard let sessionID = sessionID else { return }
        
        do {
            try await serverManager.abortSession(id: sessionID)
            status = .idle
            finalizeStreamingMessage()
            log(.info, category: .session, "Aborted session \(sessionID)")
        } catch {
            errorMessage = error.localizedDescription
            log(.error, category: .session, "Failed to abort session: \(error.localizedDescription)")
        }
    }
    
    func forkSession(atMessageID: String) async -> String? {
        guard let sessionID = sessionID else { return nil }
        
        do {
            let newSessionID = try await serverManager.forkSession(id: sessionID, messageID: atMessageID)
            log(.info, category: .session, "Forked session \(sessionID) to \(newSessionID)")
            return newSessionID
        } catch {
            errorMessage = error.localizedDescription
            log(.error, category: .session, "Failed to fork session: \(error.localizedDescription)")
            return nil
        }
    }
    
    func respondToPermission(approved: Bool) async {
        guard let sessionID = sessionID,
              let permission = pendingPermission else { return }
        
        do {
            try await serverManager.respondToPermission(
                sessionID: sessionID,
                permissionID: permission.permissionID,
                approved: approved
            )
            pendingPermission = nil
            log(.info, category: .session, "Responded to permission: \(approved)")
        } catch {
            errorMessage = error.localizedDescription
            log(.error, category: .session, "Failed to respond to permission: \(error.localizedDescription)")
        }
    }
    
    func copySessionID() {
        guard let sessionID = sessionID else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(sessionID, forType: .string)
        
        log(.info, category: .session, "Copied session ID: \(sessionID)")
    }
    
    private func loadMessages() async {
        guard let sessionID = sessionID else { return }
        
        do {
            let ocMessages = try await serverManager.getMessages(sessionID: sessionID)
            messages = ocMessages.map { ocMessage in
                var toolUseInfo: ToolUseInfo? = nil
                for part in ocMessage.parts {
                    if part.type == "tool_use", let tool = part.toolUse {
                        toolUseInfo = ToolUseInfo(
                            name: tool.name ?? "unknown",
                            status: ToolUseStatus(rawValue: tool.status ?? "pending") ?? .pending,
                            input: tool.input,
                            output: tool.output,
                            permissionID: tool.permissionID
                        )
                        break
                    }
                }
                
                return ChatMessage(
                    id: ocMessage.id,
                    role: ocMessage.role,
                    content: ocMessage.content,
                    createdAt: Date(),
                    toolUse: toolUseInfo,
                    isStreaming: false
                )
            }
            log(.debug, category: .session, "Loaded \(messages.count) messages for session \(sessionID)")
        } catch {
            log(.error, category: .session, "Failed to load messages: \(error.localizedDescription)")
        }
    }
    
    private func handleSSEEvent(_ event: SSEEvent) {
        log(.debug, category: .session, "Received SSE event: \(event.type), my sessionID: \(sessionID ?? "nil")")
        
        guard let eventSessionID = event.sessionID,
              eventSessionID == sessionID else {
            return
        }
        
        log(.info, category: .session, "Processing SSE event for session \(sessionID ?? ""): \(event.type)")
        
        switch event.type {
        case .sessionStatus:
            if let status = event.status {
                log(.info, category: .session, "Session status: \(status)")
                if status == "idle" {
                    self.status = .idle
                    finalizeStreamingMessage()
                } else if status == "busy" {
                    self.status = .running
                }
            }
            
        case .sessionIdle:
            log(.info, category: .session, "Session idle")
            status = .idle
            finalizeStreamingMessage()
            
        case .sessionError:
            if let errorMessage = event.error {
                log(.error, category: .session, "Session error: \(errorMessage)")
                status = .error
                self.errorMessage = errorMessage
                finalizeStreamingMessage()
            }
            
        case .messagePartDelta:
            if let messageID = event.messageID,
               let delta = event.delta,
               let field = event.field,
               field == "text" {
                log(.info, category: .session, "Message part delta: messageID=\(messageID), delta=\(delta.truncated(to: 50))")
                handleStreamingContent(messageID: messageID, content: delta)
            }
            
        case .messagePartUpdated:
            log(.info, category: .session, "Message part updated: partID=\(event.partID ?? "nil")")
            
        case .messageUpdated:
            log(.info, category: .session, "Message updated: messageID=\(event.messageID ?? "nil"), role=\(event.role ?? "nil")")
            
        case .permissionAsked:
            log(.info, category: .session, "Permission asked")
            if let requestID = event.requestID {
                let tool = event.toolName ?? "unknown"
                let message = event.description ?? ""
                pendingPermission = PermissionRequestedData(
                    permissionID: requestID,
                    toolName: tool,
                    description: message
                )
            }
            
        case .serverConnected, .serverHeartbeat:
            break
            
        default:
            log(.debug, category: .session, "Unhandled event type: \(event.type)")
        }
    }
    
    private func handleStreamingContent(messageID: String, content: String) {
        if let index = messages.firstIndex(where: { $0.id == messageID }) {
            messages[index].content += content
        } else {
            let newMessage = ChatMessage(
                id: messageID,
                role: .assistant,
                content: content,
                createdAt: Date(),
                isStreaming: true
            )
            messages.append(newMessage)
            streamingMessageID = messageID
        }
    }
    
    private func handleCompletedMessage(messageID: String, content: String, role: MessageRole) {
        if let index = messages.firstIndex(where: { $0.id == messageID }) {
            messages[index].content = content
            messages[index].isStreaming = false
        } else {
            let newMessage = ChatMessage(
                id: messageID,
                role: role,
                content: content,
                createdAt: Date(),
                isStreaming: false
            )
            messages.append(newMessage)
        }
        streamingMessageID = nil
    }
    
    private func finalizeStreamingMessage() {
        if let messageID = streamingMessageID,
           let index = messages.firstIndex(where: { $0.id == messageID }) {
            messages[index].isStreaming = false
        }
        streamingMessageID = nil
    }
}
