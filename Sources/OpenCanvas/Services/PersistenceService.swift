import Foundation
import SwiftUI

@MainActor
@Observable
final class PersistenceService {
    static let shared = PersistenceService()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let canvasNodes = "canvasNodes"
        static let serverURL = "serverURL"
        static let canvasBackgroundStyle = "canvasBackgroundStyle"
        static let defaultNodeColor = "defaultNodeColor"
        static let logLevel = "logLevel"
        static let canvasOffset = "canvasOffset"
        static let canvasScale = "canvasScale"
        static let nodeSpacing = "nodeSpacing"
        static let normalFontSize = "normalFontSize"
        static let expandedFontSize = "expandedFontSize"
    }
    
    private init() {}
    
    func saveNodes(_ nodes: [CanvasNode]) {
        let nodeDicts = nodes.map { node -> [String: Any] in
            return [
                "id": node.id.uuidString,
                "title": node.title,
                "x": node.position.x,
                "y": node.position.y,
                "sessionID": node.sessionID ?? "",
                "color": node.color.rawValue,
                "minimized": node.isMinimized,
                "width": node.size.width,
                "height": node.size.height
            ]
        }
        
        defaults.set(nodeDicts, forKey: Keys.canvasNodes)
        log(.debug, category: .storage, "Saved \(nodes.count) nodes")
    }
    
    func loadNodes() -> [CanvasNode] {
        guard let nodeDicts = defaults.array(forKey: Keys.canvasNodes) as? [[String: Any]] else {
            return []
        }
        
        let nodes = nodeDicts.compactMap { dict -> CanvasNode? in
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let title = dict["title"] as? String,
                  let x = dict["x"] as? CGFloat,
                  let y = dict["y"] as? CGFloat,
                  let colorRaw = dict["color"] as? String,
                  let color = NodeColor(rawValue: colorRaw) else {
                return nil
            }
            
            let sessionID = dict["sessionID"] as? String
            let minimized = dict["minimized"] as? Bool ?? false
            let width = dict["width"] as? CGFloat ?? 320
            let height = dict["height"] as? CGFloat ?? 480
            
            return CanvasNode(
                id: id,
                title: title,
                position: CGPoint(x: x, y: y),
                sessionID: sessionID?.isEmpty == false ? sessionID : nil,
                color: color,
                isMinimized: minimized,
                size: CGSize(width: width, height: height)
            )
        }
        
        log(.debug, category: .storage, "Loaded \(nodes.count) nodes")
        return nodes
    }
    
    func saveServerURL(_ url: String) {
        defaults.set(url, forKey: Keys.serverURL)
        log(.debug, category: .storage, "Saved server URL: \(url)")
    }
    
    func loadServerURL() -> String {
        defaults.string(forKey: Keys.serverURL) ?? "http://localhost:4097"
    }
    
    func saveCanvasBackgroundStyle(_ style: CanvasBackgroundStyle) {
        defaults.set(style.rawValue, forKey: Keys.canvasBackgroundStyle)
        log(.debug, category: .storage, "Saved canvas background style: \(style.rawValue)")
    }
    
    func loadCanvasBackgroundStyle() -> CanvasBackgroundStyle {
        guard let rawValue = defaults.string(forKey: Keys.canvasBackgroundStyle),
              let style = CanvasBackgroundStyle(rawValue: rawValue) else {
            return .dots
        }
        return style
    }
    
    func saveDefaultNodeColor(_ color: NodeColor) {
        defaults.set(color.rawValue, forKey: Keys.defaultNodeColor)
        log(.debug, category: .storage, "Saved default node color: \(color.rawValue)")
    }
    
    func loadDefaultNodeColor() -> NodeColor {
        guard let rawValue = defaults.string(forKey: Keys.defaultNodeColor),
              let color = NodeColor(rawValue: rawValue) else {
            return .blue
        }
        return color
    }
    
    func saveLogLevel(_ level: LogLevel) {
        defaults.set(level.rawValue, forKey: Keys.logLevel)
        AppLogger.shared.setLogLevel(level)
        log(.debug, category: .storage, "Saved log level: \(level.rawValue)")
    }
    
    func loadLogLevel() -> LogLevel {
        guard let rawValue = defaults.string(forKey: Keys.logLevel),
              let level = LogLevel(rawValue: rawValue) else {
            return .info
        }
        return level
    }
    
    func saveCanvasOffset(_ offset: CGSize) {
        defaults.set(["width": offset.width, "height": offset.height], forKey: Keys.canvasOffset)
    }
    
    func loadCanvasOffset() -> CGSize {
        guard let dict = defaults.dictionary(forKey: Keys.canvasOffset),
              let width = dict["width"] as? CGFloat,
              let height = dict["height"] as? CGFloat else {
            return .zero
        }
        return CGSize(width: width, height: height)
    }
    
    func saveCanvasScale(_ scale: CGFloat) {
        defaults.set(scale, forKey: Keys.canvasScale)
    }
    
    func loadCanvasScale() -> CGFloat {
        let scale = defaults.double(forKey: Keys.canvasScale)
        return scale > 0 ? scale : 1.0
    }

    func saveNodeSpacing(_ spacing: CGFloat) {
        defaults.set(Double(spacing), forKey: Keys.nodeSpacing)
        log(.debug, category: .storage, "Saved node spacing: \(spacing)")
    }

    func loadNodeSpacing() -> CGFloat {
        let spacing = defaults.double(forKey: Keys.nodeSpacing)
        return spacing > 0 ? CGFloat(spacing) : 40
    }

    func saveNormalFontSize(_ size: CGFloat) {
        defaults.set(Double(size), forKey: Keys.normalFontSize)
        log(.debug, category: .storage, "Saved normal font size: \(size)")
    }

    func loadNormalFontSize() -> CGFloat {
        let size = defaults.double(forKey: Keys.normalFontSize)
        return size > 0 ? CGFloat(size) : 13
    }

    func saveExpandedFontSize(_ size: CGFloat) {
        defaults.set(Double(size), forKey: Keys.expandedFontSize)
        log(.debug, category: .storage, "Saved expanded font size: \(size)")
    }

    func loadExpandedFontSize() -> CGFloat {
        let size = defaults.double(forKey: Keys.expandedFontSize)
        return size > 0 ? CGFloat(size) : 16
    }
}
