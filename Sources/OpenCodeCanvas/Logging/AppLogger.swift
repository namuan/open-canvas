import Foundation
import OSLog

enum LogCategory: String, CaseIterable, Sendable {
    case app = "App"
    case canvas = "Canvas"
    case session = "Session"
    case network = "Network"
    case sse = "SSE"
    case ui = "UI"
    case storage = "Storage"
}

final class AppLogger: @unchecked Sendable {
    static let shared = AppLogger()
    
    private let osLog = Logger(subsystem: "com.opencodecanvas.app", category: "App")
    private let fileManager = FileManager.default
    private let logQueue = DispatchQueue(label: "com.opencodecanvas.logger", qos: .utility)
    private let logDirectory: URL
    private var currentLogFile: URL
    private var logLevel: LogLevel = .info
    private let maxFileSize: Int64 = 5 * 1024 * 1024
    private let maxArchiveFiles = 5
    
    private init() {
        let logsURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("OpenCodeCanvas", isDirectory: true)
        
        logDirectory = logsURL
        currentLogFile = logsURL.appendingPathComponent("OpenCodeCanvas.log")
        
        do {
            try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create log directory: \(error)")
        }
    }
    
    func setLogLevel(_ level: LogLevel) {
        logQueue.sync {
            self.logLevel = level
        }
    }
    
    func log(
        _ level: LogLevel,
        category: LogCategory,
        message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            if level < self.logLevel { return }
            
            let fileName = (file as NSString).lastPathComponent
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let logEntry = "\(timestamp) \(level.emoji) [\(level.rawValue)] [\(category.rawValue)] [\(fileName):\(line)] \(function) → \(message)\n"
            
            self.writeToFile(logEntry)
            self.logToOS(level: level, category: category, message: message)
        }
    }
    
    private func writeToFile(_ entry: String) {
        do {
            if fileManager.fileExists(atPath: currentLogFile.path) {
                let attributes = try fileManager.attributesOfItem(atPath: currentLogFile.path)
                if let fileSize = attributes[.size] as? Int64, fileSize >= maxFileSize {
                    rotateLog()
                }
            }
            
            if !fileManager.fileExists(atPath: currentLogFile.path) {
                fileManager.createFile(atPath: currentLogFile.path, contents: nil)
            }
            
            let fileHandle = try FileHandle(forWritingTo: currentLogFile)
            fileHandle.seekToEndOfFile()
            if let data = entry.data(using: .utf8) {
                fileHandle.write(data)
            }
            try fileHandle.close()
        } catch {
            print("Failed to write log: \(error)")
        }
    }
    
    private func rotateLog() {
        let timestamp = Int(Date().timeIntervalSince1970)
        let archiveURL = logDirectory.appendingPathComponent("OpenCodeCanvas-\(timestamp).log")
        
        do {
            try fileManager.moveItem(at: currentLogFile, to: archiveURL)
            cleanupOldArchives()
        } catch {
            print("Failed to rotate log: \(error)")
        }
    }
    
    private func cleanupOldArchives() {
        do {
            let files = try fileManager.contentsOfDirectory(
                at: logDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )
            
            let archives = files
                .filter { $0.lastPathComponent.hasPrefix("OpenCodeCanvas-") }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 < date2
                }
            
            if archives.count > maxArchiveFiles {
                for i in 0..<(archives.count - maxArchiveFiles) {
                    try fileManager.removeItem(at: archives[i])
                }
            }
        } catch {
            print("Failed to cleanup archives: \(error)")
        }
    }
    
    private func logToOS(level: LogLevel, category: LogCategory, message: String) {
        let logger = Logger(subsystem: "com.opencodecanvas.app", category: category.rawValue)
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }
    
    func getLogFileURL() -> URL {
        currentLogFile
    }
    
    func purgeLogs() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let files = try self.fileManager.contentsOfDirectory(
                    at: self.logDirectory,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                )
                for file in files {
                    try self.fileManager.removeItem(at: file)
                }
                self.fileManager.createFile(atPath: self.currentLogFile.path, contents: nil)
            } catch {
                print("Failed to purge logs: \(error)")
            }
        }
    }
}

func log(
    _ level: LogLevel,
    category: LogCategory,
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    AppLogger.shared.log(level, category: category, message: message, file: file, function: function, line: line)
}

extension LogLevel: Comparable {
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        switch (lhs, rhs) {
        case (.debug, .info), (.debug, .warning), (.debug, .error):
            return true
        case (.info, .warning), (.info, .error):
            return true
        case (.warning, .error):
            return true
        default:
            return false
        }
    }
}
