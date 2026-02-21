import Foundation
import SwiftUI
import Combine

@MainActor
@Observable
final class AppState {
    var nodes: [CanvasNode] = []
    var connections: [NodeConnection] = []
    var selectedNodeID: UUID?
    var canvasOffset: CGSize = .zero
    var canvasScale: CGFloat = 1.0
    var sidebarVisible: Bool = true
    var canvasBackgroundStyle: CanvasBackgroundStyle = .dots
    var defaultNodeColor: NodeColor = .blue
    var isConnectionMode: Bool = false
    var connectionSourceNodeID: UUID?
    
    private let serverManager = OpenCodeServerManager.shared
    private let persistenceService = PersistenceService.shared
    private var cancellables = Set<AnyCancellable>()
    
    var activeSessionCount: Int {
        nodes.filter { $0.sessionID != nil }.count
    }
    
    var selectedNode: CanvasNode? {
        nodes.first { $0.id == selectedNodeID }
    }
    
    func initialize() async {
        loadPersistedState()
        
        serverManager.configure(url: persistenceService.loadServerURL())
        await serverManager.connect()
        
        await reconcileSessions()
        
        serverManager.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleSSEEvent(event)
                }
            }
            .store(in: &cancellables)
        
        log(.info, category: .app, "AppState initialized with \(nodes.count) nodes")
    }
    
    private func loadPersistedState() {
        nodes = persistenceService.loadNodes()
        connections = persistenceService.loadConnections()
        canvasOffset = persistenceService.loadCanvasOffset()
        canvasScale = persistenceService.loadCanvasScale()
        sidebarVisible = persistenceService.loadSidebarVisible()
        canvasBackgroundStyle = persistenceService.loadCanvasBackgroundStyle()
        defaultNodeColor = persistenceService.loadDefaultNodeColor()
        
        AppLogger.shared.setLogLevel(persistenceService.loadLogLevel())
    }
    
    private func reconcileSessions() async {
        do {
            let sessions = try await serverManager.listSessions()
            let sessionIDs = Set(sessions.map { $0.id })
            
            for i in nodes.indices {
                if let sessionID = nodes[i].sessionID {
                    if sessionIDs.contains(sessionID) {
                        nodes[i].lastActivity = Date()
                        log(.info, category: .session, "Reconciled session \(sessionID) - found on server")
                    } else {
                        nodes[i].sessionID = nil
                        log(.warning, category: .session, "Session \(sessionID) not found on server")
                    }
                }
            }
            
            saveNodes()
        } catch {
            log(.error, category: .session, "Failed to reconcile sessions: \(error.localizedDescription)")
        }
    }
    
    private func handleSSEEvent(_ event: SSEEvent) {
        guard let sessionID = event.sessionID else { return }
        
        if let nodeIndex = nodes.firstIndex(where: { $0.sessionID == sessionID }) {
            nodes[nodeIndex].lastActivity = Date()
            
            switch event.type {
            case .sessionStatus:
                if let status = event.status {
                    log(.debug, category: .sse, "Session \(sessionID) status: \(status)")
                }
            case .sessionError:
                if let error = event.error {
                    log(.error, category: .sse, "Session \(sessionID) error: \(error)")
                }
            default:
                break
            }
        }
    }
    
    func addNode(at position: CGPoint? = nil) {
        let jitterX = CGFloat.random(in: -50...50)
        let jitterY = CGFloat.random(in: -50...50)
        
        let nodePosition = position ?? CGPoint(
            x: -canvasOffset.width / canvasScale + jitterX,
            y: -canvasOffset.height / canvasScale + jitterY
        )
        
        let node = CanvasNode(
            title: "Session \(nodes.count + 1)",
            position: nodePosition,
            color: defaultNodeColor
        )
        
        nodes.append(node)
        selectedNodeID = node.id
        saveNodes()
        
        log(.info, category: .canvas, "Added node \(node.id) at \(nodePosition)")
    }
    
    func removeNode(id: UUID) async {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        
        let node = nodes[index]
        
        if let sessionID = node.sessionID {
            do {
                try await serverManager.deleteSession(id: sessionID)
            } catch {
                log(.error, category: .session, "Failed to delete session \(sessionID): \(error.localizedDescription)")
            }
        }
        
        connections.removeAll { $0.sourceNodeID == id || $0.targetNodeID == id }
        nodes.remove(at: index)
        
        if selectedNodeID == id {
            selectedNodeID = nil
        }
        
        saveNodes()
        saveConnections()
        
        log(.info, category: .canvas, "Removed node \(id)")
    }
    
    func updateNodePosition(id: UUID, position: CGPoint) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        
        if nodes[index].position != position {
            nodes[index].position = position
            saveNodes()
        }
    }
    
    func updateNodeSize(id: UUID, size: CGSize) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        
        let minSize = CGSize(width: 280, height: 360)
        let clampedSize = CGSize(
            width: max(minSize.width, size.width),
            height: max(minSize.height, size.height)
        )
        
        if nodes[index].size != clampedSize {
            nodes[index].size = clampedSize
            saveNodes()
        }
    }
    
    func updateNodeTitle(id: UUID, title: String) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        
        nodes[index].title = title
        saveNodes()
        
        log(.info, category: .canvas, "Updated node \(id) title to: \(title)")
    }
    
    func updateNodeColor(id: UUID, color: NodeColor) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        
        nodes[index].color = color
        saveNodes()
        
        log(.info, category: .canvas, "Updated node \(id) color to: \(color.rawValue)")
    }
    
    func toggleNodeMinimized(id: UUID) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        
        nodes[index].isMinimized.toggle()
        saveNodes()
        
        log(.info, category: .canvas, "Toggled node \(id) minimized: \(nodes[index].isMinimized)")
    }
    
    func assignSession(nodeID: UUID, sessionID: String) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        
        nodes[index].sessionID = sessionID
        nodes[index].lastActivity = Date()
        saveNodes()
        
        log(.info, category: .session, "Assigned session \(sessionID) to node \(nodeID)")
    }
    
    func clearSession(nodeID: UUID) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        
        nodes[index].sessionID = nil
        saveNodes()
        
        log(.info, category: .session, "Cleared session from node \(nodeID)")
    }
    
    func addConnection(sourceID: UUID, targetID: UUID) {
        let exists = connections.contains { 
            $0.sourceNodeID == sourceID && $0.targetNodeID == targetID 
        }
        
        if !exists && sourceID != targetID {
            let connection = NodeConnection(sourceNodeID: sourceID, targetNodeID: targetID)
            connections.append(connection)
            saveConnections()
            
            log(.info, category: .canvas, "Added connection from \(sourceID) to \(targetID)")
        }
    }
    
    func removeConnection(id: UUID) {
        connections.removeAll { $0.id == id }
        saveConnections()
        
        log(.info, category: .canvas, "Removed connection \(id)")
    }
    
    func autoLayout() {
        let padding: CGFloat = 40
        let cols = Int(ceil(sqrt(Double(nodes.count))))
        
        for (index, _) in nodes.enumerated() {
            let row = index / cols
            let col = index % cols
            
            let x = CGFloat(col) * (320 + padding)
            let y = CGFloat(row) * (480 + padding)
            
            nodes[index].position = CGPoint(x: x, y: y)
        }
        
        saveNodes()
        
        log(.info, category: .canvas, "Auto-layout applied to \(nodes.count) nodes")
    }
    
    func resetView() {
        canvasScale = 1.0
        canvasOffset = .zero
        
        persistenceService.saveCanvasOffset(canvasOffset)
        persistenceService.saveCanvasScale(canvasScale)
        
        log(.info, category: .canvas, "Reset canvas view")
    }
    
    func zoomIn() {
        canvasScale = min(2.5, canvasScale * 1.2)
        persistenceService.saveCanvasScale(canvasScale)
    }
    
    func zoomOut() {
        canvasScale = max(0.3, canvasScale / 1.2)
        persistenceService.saveCanvasScale(canvasScale)
    }
    
    func updateCanvasOffset(_ offset: CGSize) {
        canvasOffset = offset
        persistenceService.saveCanvasOffset(offset)
    }
    
    func updateCanvasScale(_ scale: CGFloat) {
        canvasScale = scale
        persistenceService.saveCanvasScale(scale)
    }
    
    func toggleSidebar() {
        sidebarVisible.toggle()
        persistenceService.saveSidebarVisible(sidebarVisible)
        
        log(.info, category: .ui, "Toggled sidebar: \(sidebarVisible)")
    }
    
    func updateBackgroundStyle(_ style: CanvasBackgroundStyle) {
        canvasBackgroundStyle = style
        persistenceService.saveCanvasBackgroundStyle(style)
    }
    
    func updateDefaultNodeColor(_ color: NodeColor) {
        defaultNodeColor = color
        persistenceService.saveDefaultNodeColor(color)
    }
    
    func clearCanvas() {
        for node in nodes {
            if let sessionID = node.sessionID {
                Task {
                    try? await serverManager.deleteSession(id: sessionID)
                }
            }
        }
        
        nodes.removeAll()
        connections.removeAll()
        selectedNodeID = nil
        
        saveNodes()
        saveConnections()
        
        log(.info, category: .canvas, "Cleared canvas")
    }
    
    func duplicateNode(id: UUID) {
        guard let node = nodes.first(where: { $0.id == id }) else { return }
        
        let newNode = CanvasNode(
            title: node.title,
            position: CGPoint(x: node.position.x + 50, y: node.position.y + 50),
            color: node.color
        )
        
        nodes.append(newNode)
        saveNodes()
        
        log(.info, category: .canvas, "Duplicated node \(id) to \(newNode.id)")
    }
    
    func selectNextNode() {
        guard !nodes.isEmpty else { return }
        
        if let currentID = selectedNodeID,
           let currentIndex = nodes.firstIndex(where: { $0.id == currentID }) {
            let nextIndex = (currentIndex + 1) % nodes.count
            selectedNodeID = nodes[nextIndex].id
        } else {
            selectedNodeID = nodes.first?.id
        }
    }
    
    private func saveNodes() {
        persistenceService.saveNodes(nodes)
    }
    
    private func saveConnections() {
        persistenceService.saveConnections(connections)
    }
}
