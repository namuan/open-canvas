import Foundation
import SwiftUI
import Combine

@MainActor
@Observable
final class AppState {
    var nodes: [CanvasNode] = []
    var selectedNodeID: UUID?
    var selectedNodeIDs: Set<UUID> = []
    var canvasOffset: CGSize = .zero
    var canvasScale: CGFloat = 1.0
    var canvasViewportSize: CGSize = .zero
    var sidebarVisible: Bool = false
    var canvasBackgroundStyle: CanvasBackgroundStyle = .dots
    var defaultNodeColor: NodeColor = .blue
    var nodeSpacing: CGFloat = 40
    private var maximizedNodeSnapshots: [UUID: NodeFrameSnapshot] = [:]
    
    private let serverManager = OpenCodeServerManager.shared
    private let persistenceService = PersistenceService.shared
    private var cancellables = Set<AnyCancellable>()
    private var lastActivityUpdateBySessionID: [String: Date] = [:]
    private var scaleSaveTask: Task<Void, Never>?
    private var offsetSaveTask: Task<Void, Never>?
    
    var activeSessionCount: Int {
        nodes.filter { $0.sessionID != nil }.count
    }
    
    var selectedNode: CanvasNode? {
        if let selectedNodeID {
            return nodes.first { $0.id == selectedNodeID }
        }
        if let firstSelectedID = selectedNodeIDs.first {
            return nodes.first { $0.id == firstSelectedID }
        }
        return nil
    }

    var hasSelection: Bool {
        !effectiveSelectedNodeIDs.isEmpty
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
        canvasOffset = persistenceService.loadCanvasOffset()
        canvasScale = persistenceService.loadCanvasScale()
        sidebarVisible = false
        persistenceService.saveSidebarVisible(false)
        canvasBackgroundStyle = persistenceService.loadCanvasBackgroundStyle()
        defaultNodeColor = persistenceService.loadDefaultNodeColor()
        nodeSpacing = persistenceService.loadNodeSpacing()
        
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
            if shouldUpdateLastActivity(for: event.type),
               shouldRefreshActivityTimestamp(for: sessionID) {
                let now = Date()
                nodes[nodeIndex].lastActivity = now
                lastActivityUpdateBySessionID[sessionID] = now
            }
            
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

    private func shouldUpdateLastActivity(for eventType: SSEEventType) -> Bool {
        switch eventType {
        case .sessionStatus, .sessionIdle, .sessionError, .messageUpdated, .messagePartUpdated, .permissionAsked:
            return true
        default:
            return false
        }
    }

    private func shouldRefreshActivityTimestamp(for sessionID: String) -> Bool {
        let interval: TimeInterval = 2.0
        guard let lastUpdate = lastActivityUpdateBySessionID[sessionID] else {
            return true
        }
        return Date().timeIntervalSince(lastUpdate) >= interval
    }
    
    func addNode(at position: CGPoint? = nil) {
        let defaultNodeSize = CanvasNode().size
        let horizontalGap = nodeSpacing
        let spawnPadding: CGFloat = 32
        let shouldFocusNewNode = (position == nil)

        let topLeftSpawnPosition: CGPoint = {
            guard canvasViewportSize.width > 0, canvasViewportSize.height > 0 else {
                return CGPoint(
                    x: -canvasOffset.width / canvasScale,
                    y: -canvasOffset.height / canvasScale
                )
            }

            let worldTopLeft = CGPoint(
                x: (-canvasOffset.width - canvasViewportSize.width / 2) / canvasScale,
                y: (-canvasOffset.height - canvasViewportSize.height / 2) / canvasScale
            )

            return CGPoint(
                x: worldTopLeft.x + spawnPadding + defaultNodeSize.width / 2,
                y: worldTopLeft.y + spawnPadding + defaultNodeSize.height / 2
            )
        }()

        var nodePosition = position ?? topLeftSpawnPosition

        if position == nil {
            let newWidth = defaultNodeSize.width
            let spawnLeftEdge = topLeftSpawnPosition.x - newWidth / 2
            let rowTolerance: CGFloat = 120

            let rowNodes = nodes.filter { abs($0.position.y - topLeftSpawnPosition.y) <= rowTolerance }
            let candidateNodes = rowNodes.filter {
                let rightEdge = $0.position.x + nodeWidth(for: $0) / 2
                return rightEdge >= spawnLeftEdge - 1
            }

            if let anchorNode = candidateNodes.max(by: {
                ($0.position.x + nodeWidth(for: $0) / 2) < ($1.position.x + nodeWidth(for: $1) / 2)
            }) {
                let shiftAmount = (nodeWidth(for: anchorNode) / 2) + horizontalGap + (newWidth / 2)
                nodePosition = CGPoint(
                    x: anchorNode.position.x + shiftAmount,
                    y: topLeftSpawnPosition.y
                )
            }
        }
        
        let node = CanvasNode(
            title: "Session \(nodes.count + 1)",
            position: nodePosition,
            color: defaultNodeColor
        )
        
        nodes.append(node)
        selectNode(node.id)

        if shouldFocusNewNode {
            focusCanvas(onWorldPosition: nodePosition, nodeSize: defaultNodeSize, padding: spawnPadding)
        }

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
        
        nodes.remove(at: index)
        
        if selectedNodeID == id {
            selectedNodeID = nil
        }
        selectedNodeIDs.remove(id)
        maximizedNodeSnapshots.removeValue(forKey: id)
        if selectedNodeID == nil, let fallbackID = selectedNodeIDs.first {
            selectedNodeID = fallbackID
        }
        
        saveNodes()
        
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

    func isNodeMaximized(_ id: UUID) -> Bool {
        maximizedNodeSnapshots[id] != nil
    }

    func toggleNodeMaximized(id: UUID) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }

        if let snapshot = maximizedNodeSnapshots[id] {
            nodes[index].position = snapshot.position
            nodes[index].size = snapshot.size
            nodes[index].isMinimized = snapshot.isMinimized
            maximizedNodeSnapshots.removeValue(forKey: id)
            saveNodes()
            log(.info, category: .canvas, "Restored node \(id) from maximized state")
            return
        }

        guard canvasViewportSize.width > 0, canvasViewportSize.height > 0 else { return }

        maximizedNodeSnapshots[id] = NodeFrameSnapshot(
            position: nodes[index].position,
            size: nodes[index].size,
            isMinimized: nodes[index].isMinimized
        )

        let viewportInset: CGFloat = 20
        let targetSize = CGSize(
            width: max(280, (canvasViewportSize.width - viewportInset * 2) / canvasScale),
            height: max(360, (canvasViewportSize.height - viewportInset * 2) / canvasScale)
        )
        let viewportWorldCenter = CGPoint(
            x: -canvasOffset.width / canvasScale,
            y: -canvasOffset.height / canvasScale
        )

        nodes[index].isMinimized = false
        nodes[index].size = targetSize
        nodes[index].position = viewportWorldCenter

        saveNodes()
        log(.info, category: .canvas, "Maximized node \(id)")
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

        if nodes[index].isMinimized == false, maximizedNodeSnapshots[id] != nil {
            maximizedNodeSnapshots.removeValue(forKey: id)
        }

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
    
    func autoLayout() {
        let targetIDs = effectiveSelectedNodeIDs
        let targetIndices: [Int]

        if targetIDs.isEmpty {
            targetIndices = Array(nodes.indices)
        } else {
            targetIndices = nodes.indices.filter { targetIDs.contains(nodes[$0].id) }
        }

        guard !targetIndices.isEmpty else { return }

        let padding: CGFloat = 40
        let cols = Int(ceil(sqrt(Double(targetIndices.count))))

        var colWidths = Array(repeating: CGFloat(0), count: cols)
        let rowCount = Int(ceil(Double(targetIndices.count) / Double(cols)))
        var rowHeights = Array(repeating: CGFloat(0), count: rowCount)

        for (index, nodeIndex) in targetIndices.enumerated() {
            let row = index / cols
            let col = index % cols
            colWidths[col] = max(colWidths[col], nodeWidth(for: nodes[nodeIndex]))
            rowHeights[row] = max(rowHeights[row], nodeHeight(for: nodes[nodeIndex]))
        }

        var colCenterX = Array(repeating: CGFloat(0), count: cols)
        var runningX: CGFloat = 0
        for col in 0..<cols {
            colCenterX[col] = runningX + colWidths[col] / 2
            runningX += colWidths[col] + padding
        }

        var rowCenterY = Array(repeating: CGFloat(0), count: rowCount)
        var runningY: CGFloat = 0
        for row in 0..<rowCount {
            rowCenterY[row] = runningY + rowHeights[row] / 2
            runningY += rowHeights[row] + padding
        }

        for (index, nodeIndex) in targetIndices.enumerated() {
            let row = index / cols
            let col = index % cols
            nodes[nodeIndex].position = CGPoint(x: colCenterX[col], y: rowCenterY[row])
        }

        fitNodesInViewport(nodeIndices: targetIndices)
        
        saveNodes()
        
        log(.info, category: .canvas, "Auto-layout applied to \(targetIndices.count) nodes")
    }
    
    func resetView() {
        if nodes.isEmpty {
            canvasScale = 1.0
            canvasOffset = .zero
            persistenceService.saveCanvasOffset(.zero)
            persistenceService.saveCanvasScale(1.0)
            log(.info, category: .canvas, "Reset canvas view (no nodes)")
            return
        }

        let allIndices = Array(nodes.indices)
        fitNodesInViewport(nodeIndices: allIndices)
        log(.info, category: .canvas, "Reset canvas view (fit all nodes)")
    }
    
    func zoomIn() {
        updateCanvasScale(min(2.5, canvasScale * 1.2))
    }
    
    func zoomOut() {
        updateCanvasScale(max(0.3, canvasScale / 1.2))
    }
    
    func updateCanvasOffset(_ offset: CGSize) {
        canvasOffset = offset
        offsetSaveTask?.cancel()
        offsetSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            self.persistenceService.saveCanvasOffset(offset)
        }
    }
    
    func updateCanvasScale(_ scale: CGFloat) {
        canvasScale = scale
        scaleSaveTask?.cancel()
        scaleSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            self.persistenceService.saveCanvasScale(scale)
        }
    }

    func updateCanvasViewportSize(_ size: CGSize) {
        guard canvasViewportSize != size else { return }
        canvasViewportSize = size
    }
    
    func toggleSidebar() {
        sidebarVisible.toggle()
        persistenceService.saveSidebarVisible(sidebarVisible)
        
        log(.info, category: .ui, "Toggled sidebar: \(sidebarVisible)")
    }
    
    func setSidebarVisible(_ visible: Bool) {
        guard sidebarVisible != visible else { return }
        
        sidebarVisible = visible
        persistenceService.saveSidebarVisible(visible)
        
        log(.info, category: .ui, "Set sidebar visibility: \(visible)")
    }
    
    func updateBackgroundStyle(_ style: CanvasBackgroundStyle) {
        canvasBackgroundStyle = style
        persistenceService.saveCanvasBackgroundStyle(style)
    }
    
    func updateDefaultNodeColor(_ color: NodeColor) {
        defaultNodeColor = color
        persistenceService.saveDefaultNodeColor(color)
    }

    func updateNodeSpacing(_ spacing: CGFloat) {
        let clamped = min(160, max(0, spacing))
        nodeSpacing = clamped
        persistenceService.saveNodeSpacing(clamped)
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
        clearSelection()
        
        saveNodes()
        
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
        selectNode(newNode.id)
        saveNodes()
        
        log(.info, category: .canvas, "Duplicated node \(id) to \(newNode.id)")
    }
    
    func selectNextNode() {
        guard !nodes.isEmpty else { return }
        
        if let currentID = selectedNodeID,
           let currentIndex = nodes.firstIndex(where: { $0.id == currentID }) {
            let nextIndex = (currentIndex + 1) % nodes.count
            selectNode(nodes[nextIndex].id)
        } else {
            if let firstID = nodes.first?.id {
                selectNode(firstID)
            }
        }
    }

    func selectNode(_ id: UUID) {
        selectedNodeID = id
        selectedNodeIDs = [id]
    }

    func selectAllNodes() {
        let allIDs = Set(nodes.map(\.id))
        selectNodes(allIDs)
        log(.info, category: .canvas, "Selected all nodes: \(allIDs.count)")
    }

    func clearSelection() {
        selectedNodeID = nil
        selectedNodeIDs.removeAll()
    }

    func isNodeSelected(_ id: UUID) -> Bool {
        effectiveSelectedNodeIDs.contains(id)
    }

    func selectNodes(_ ids: Set<UUID>) {
        selectedNodeIDs = ids
        selectedNodeID = nodes.first(where: { ids.contains($0.id) })?.id
    }

    func deleteSelectedNodes() async {
        let idsToDelete = Array(effectiveSelectedNodeIDs)
        guard !idsToDelete.isEmpty else { return }

        for id in idsToDelete {
            await removeNode(id: id)
        }

        clearSelection()
    }

    private var effectiveSelectedNodeIDs: Set<UUID> {
        if !selectedNodeIDs.isEmpty {
            return selectedNodeIDs
        }
        if let selectedNodeID {
            return [selectedNodeID]
        }
        return []
    }

    private func nodeWidth(for node: CanvasNode) -> CGFloat {
        node.isMinimized ? 280 : node.size.width
    }

    private func nodeHeight(for node: CanvasNode) -> CGFloat {
        node.isMinimized ? 72 : node.size.height
    }

    private func fitNodesInViewport(nodeIndices: [Int]) {
        guard canvasViewportSize.width > 0, canvasViewportSize.height > 0, !nodeIndices.isEmpty else {
            return
        }

        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity

        for index in nodeIndices {
            let node = nodes[index]
            let width = nodeWidth(for: node)
            let height = nodeHeight(for: node)
            minX = min(minX, node.position.x - width / 2)
            minY = min(minY, node.position.y - height / 2)
            maxX = max(maxX, node.position.x + width / 2)
            maxY = max(maxY, node.position.y + height / 2)
        }

        guard minX.isFinite, minY.isFinite, maxX.isFinite, maxY.isFinite else { return }

        let contentWidth = max(1, maxX - minX)
        let contentHeight = max(1, maxY - minY)
        let inset: CGFloat = 32
        let availableWidth = max(1, canvasViewportSize.width - inset * 2)
        let availableHeight = max(1, canvasViewportSize.height - inset * 2)

        let fittingScale = min(availableWidth / contentWidth, availableHeight / contentHeight)
        let clampedScale = min(2.5, max(0.3, fittingScale))
        updateCanvasScale(clampedScale)

        let center = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let centeredOffset = CGSize(
            width: -center.x * clampedScale,
            height: -center.y * clampedScale
        )
        updateCanvasOffset(centeredOffset)
    }

    private func focusCanvas(onWorldPosition worldPosition: CGPoint, nodeSize: CGSize, padding: CGFloat) {
        guard canvasViewportSize.width > 0, canvasViewportSize.height > 0 else { return }

        let desiredViewCenter = CGPoint(
            x: padding + nodeSize.width / 2,
            y: padding + nodeSize.height / 2
        )

        let focusedOffset = CGSize(
            width: desiredViewCenter.x - worldPosition.x * canvasScale - canvasViewportSize.width / 2,
            height: desiredViewCenter.y - worldPosition.y * canvasScale - canvasViewportSize.height / 2
        )
        updateCanvasOffset(focusedOffset)
    }
    
    private func saveNodes() {
        persistenceService.saveNodes(nodes)
    }
    
}

private struct NodeFrameSnapshot {
    let position: CGPoint
    let size: CGSize
    let isMinimized: Bool
}
