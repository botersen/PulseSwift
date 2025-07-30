import Foundation
import os.log

// MARK: - Logger (Production-Ready)
protocol LoggerProtocol {
    func log(_ level: LogLevel, message: String, category: LogCategory, file: String, function: String, line: Int)
    func logEvent(_ event: AnalyticsEvent)
    func logError(_ error: Error, context: [String: Any]?, file: String, function: String, line: Int)
    func logPerformance(_ metric: PerformanceMetric)
}

final class Logger: LoggerProtocol {
    
    // MARK: - Singleton
    static let shared = Logger()
    
    // MARK: - Configuration
    private let config = AppConfiguration.current
    private let fileLogger = FileLogger()
    private let analyticsService = AnalyticsService()
    
    // MARK: - OS Loggers
    private let osLoggers: [LogCategory: OSLog] = [
        .app: OSLog(subsystem: "com.pulse.app", category: "app"),
        .network: OSLog(subsystem: "com.pulse.app", category: "network"),
        .camera: OSLog(subsystem: "com.pulse.app", category: "camera"),
        .auth: OSLog(subsystem: "com.pulse.app", category: "auth"),
        .media: OSLog(subsystem: "com.pulse.app", category: "media"),
        .performance: OSLog(subsystem: "com.pulse.app", category: "performance"),
        .security: OSLog(subsystem: "com.pulse.app", category: "security"),
        .analytics: OSLog(subsystem: "com.pulse.app", category: "analytics")
    ]
    
    private init() {
        print("✅ Logger: Initialized with configuration - \(config.environment)")
    }
    
    // MARK: - Public Logging Methods
    func log(_ level: LogLevel, message: String, category: LogCategory, file: String = #file, function: String = #function, line: Int = #line) {
        // Check if logging is enabled for this level
        guard shouldLog(level: level) else { return }
        
        let logEntry = LogEntry(
            level: level,
            message: message,
            category: category,
            file: extractFilename(from: file),
            function: function,
            line: line,
            timestamp: Date()
        )
        
        // Log to multiple destinations
        logToConsole(logEntry)
        logToOS(logEntry)
        
        if config.features.verboseLogging || level.rawValue >= LogLevel.error.rawValue {
            logToFile(logEntry)
        }
        
        // Send critical errors to crash reporting
        if level == .critical && config.features.crashReporting {
            sendToCrashReporting(logEntry)
        }
    }
    
    func logEvent(_ event: AnalyticsEvent) {
        guard config.analytics.enabled else { return }
        
        analyticsService.track(event)
        
        if config.features.verboseLogging {
            log(.info, message: "Event: \(event.name) - \(event.parameters)", category: .analytics)
        }
    }
    
    func logError(_ error: Error, context: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var message = "Error: \(error.localizedDescription)"
        
        if let context = context {
            let contextString = context.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            message += " | Context: \(contextString)"
        }
        
        log(.error, message: message, category: .app, file: file, function: function, line: line)
        
        // Track error event
        if config.analytics.enabled {
            let errorEvent = AnalyticsEvent(
                name: "error_occurred",
                parameters: [
                    "error_type": String(describing: type(of: error)),
                    "error_description": error.localizedDescription,
                    "file": extractFilename(from: file),
                    "function": function,
                    "line": line
                ]
            )
            logEvent(errorEvent)
        }
    }
    
    func logPerformance(_ metric: PerformanceMetric) {
        guard config.analytics.performanceMetrics else { return }
        
        let message = "Performance: \(metric.name) - \(metric.duration)ms"
        log(.info, message: message, category: .performance)
        
        // Track performance event
        let performanceEvent = AnalyticsEvent(
            name: "performance_metric",
            parameters: [
                "metric_name": metric.name,
                "duration_ms": metric.duration,
                "category": metric.category.rawValue
            ]
        )
        logEvent(performanceEvent)
    }
    
    // MARK: - Private Methods
    private func shouldLog(level: LogLevel) -> Bool {
        if config.isDebug {
            return true // Log everything in debug
        }
        
        // In production, only log warnings and above
        return level.rawValue >= LogLevel.warning.rawValue
    }
    
    private func logToConsole(_ entry: LogEntry) {
        let emoji = entry.level.emoji
        let timestamp = formatTimestamp(entry.timestamp)
        let location = "[\(entry.file):\(entry.line)]"
        
        print("\(emoji) \(timestamp) [\(entry.category.rawValue.uppercased())] \(location) \(entry.message)")
    }
    
    private func logToOS(_ entry: LogEntry) {
        guard let osLog = osLoggers[entry.category] else { return }
        
        let logType: OSLogType
        switch entry.level {
        case .verbose, .debug:
            logType = .debug
        case .info:
            logType = .info
        case .warning:
            logType = .default
        case .error:
            logType = .error
        case .critical:
            logType = .fault
        }
        
        os_log("%{public}@", log: osLog, type: logType, entry.message)
    }
    
    private func logToFile(_ entry: LogEntry) {
        fileLogger.write(entry)
    }
    
    private func sendToCrashReporting(_ entry: LogEntry) {
        // This would integrate with Firebase Crashlytics or similar
        print("🚨 CRITICAL: \(entry.message)")
    }
    
    private func extractFilename(from path: String) -> String {
        return (path as NSString).lastPathComponent
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

// MARK: - Convenience Extensions
extension Logger {
    
    // Convenience methods for different log levels
    func verbose(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(.verbose, message: message, category: category, file: file, function: function, line: line)
    }
    
    func debug(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message: message, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message: message, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message: message, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message: message, category: category, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(.critical, message: message, category: category, file: file, function: function, line: line)
    }
}

// MARK: - Log Levels
enum LogLevel: Int, CaseIterable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5
    
    var emoji: String {
        switch self {
        case .verbose: return "💬"
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}

// MARK: - Log Categories
enum LogCategory: String, CaseIterable {
    case app = "app"
    case network = "network"
    case camera = "camera"
    case auth = "auth"
    case media = "media"
    case performance = "performance"
    case security = "security"
    case analytics = "analytics"
}

// MARK: - Log Entry
struct LogEntry {
    let level: LogLevel
    let message: String
    let category: LogCategory
    let file: String
    let function: String
    let line: Int
    let timestamp: Date
    
    var formattedMessage: String {
        let timestampString = ISO8601DateFormatter().string(from: timestamp)
        return "[\(timestampString)] [\(level.emoji)] [\(category.rawValue.uppercased())] [\(file):\(line)] \(message)"
    }
}

// MARK: - File Logger
private class FileLogger {
    private let logQueue = DispatchQueue(label: "com.pulse.filelogger", qos: .utility)
    private let logFileURL: URL
    private let maxFileSize: Int = 10 * 1024 * 1024 // 10MB
    private let maxFiles = 5
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = documentsPath.appendingPathComponent("pulse_logs.txt")
        
        // Create log file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        }
    }
    
    func write(_ entry: LogEntry) {
        logQueue.async { [weak self] in
            self?.writeEntry(entry)
        }
    }
    
    private func writeEntry(_ entry: LogEntry) {
        guard let data = (entry.formattedMessage + "\n").data(using: .utf8) else { return }
        
        // Check file size and rotate if needed
        if let fileSize = try? FileManager.default.attributesOfItem(atPath: logFileURL.path)[.size] as? Int,
           fileSize > maxFileSize {
            rotateLogFile()
        }
        
        // Append to log file
        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        }
    }
    
    private func rotateLogFile() {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Move current log file to backup
        let timestamp = Int(Date().timeIntervalSince1970)
        let backupURL = documentsPath.appendingPathComponent("pulse_logs_\(timestamp).txt")
        
        try? fileManager.moveItem(at: logFileURL, to: backupURL)
        
        // Create new log file
        fileManager.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        
        // Clean up old log files
        cleanupOldLogFiles()
    }
    
    private func cleanupOldLogFiles() {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.creationDateKey])
            let logFiles = files.filter { $0.lastPathComponent.hasPrefix("pulse_logs_") }
                .sorted { url1, url2 in
                    let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    return date1! > date2!
                }
            
            // Keep only the most recent files
            if logFiles.count > maxFiles {
                for fileURL in logFiles.dropFirst(maxFiles) {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            print("Failed to cleanup old log files: \(error)")
        }
    }
}

// MARK: - Analytics Service
private class AnalyticsService {
    private let config = AppConfiguration.current
    private let eventQueue = DispatchQueue(label: "com.pulse.analytics", qos: .utility)
    
    func track(_ event: AnalyticsEvent) {
        guard config.analytics.enabled else { return }
        
        eventQueue.async {
            self.sendEvent(event)
        }
    }
    
    private func sendEvent(_ event: AnalyticsEvent) {
        // This would integrate with Firebase Analytics, Mixpanel, etc.
        if config.features.verboseLogging {
            print("📊 Analytics: \(event.name) - \(event.parameters)")
        }
        
        // For now, just store events locally for testing
        storeEventLocally(event)
    }
    
    private func storeEventLocally(_ event: AnalyticsEvent) {
        let userDefaults = UserDefaults.standard
        var storedEvents = userDefaults.array(forKey: "analytics_events") as? [[String: Any]] ?? []
        
        var eventData: [String: Any] = [
            "name": event.name,
            "timestamp": event.timestamp.timeIntervalSince1970
        ]
        
        if !event.parameters.isEmpty {
            eventData["parameters"] = event.parameters
        }
        
        storedEvents.append(eventData)
        
        // Keep only the last 100 events
        if storedEvents.count > 100 {
            storedEvents = Array(storedEvents.suffix(100))
        }
        
        userDefaults.set(storedEvents, forKey: "analytics_events")
    }
}

// MARK: - Analytics Event
struct AnalyticsEvent {
    let name: String
    let parameters: [String: Any]
    let timestamp: Date
    
    init(name: String, parameters: [String: Any] = [:]) {
        self.name = name
        self.parameters = parameters
        self.timestamp = Date()
    }
}

// MARK: - Performance Metric
struct PerformanceMetric {
    let name: String
    let duration: TimeInterval
    let category: PerformanceCategory
    let metadata: [String: Any]
    
    init(name: String, duration: TimeInterval, category: PerformanceCategory, metadata: [String: Any] = [:]) {
        self.name = name
        self.duration = duration * 1000 // Convert to milliseconds
        self.category = category
        self.metadata = metadata
    }
}

enum PerformanceCategory: String {
    case network = "network"
    case camera = "camera"
    case media = "media"
    case auth = "auth"
    case ui = "ui"
    case database = "database"
}

// MARK: - Performance Timer
class PerformanceTimer {
    private let name: String
    private let category: PerformanceCategory
    private let startTime: CFTimeInterval
    private var metadata: [String: Any] = [:]
    
    init(name: String, category: PerformanceCategory) {
        self.name = name
        self.category = category
        self.startTime = Date().timeIntervalSince1970
    }
    
    func addMetadata(_ key: String, value: Any) {
        metadata[key] = value
    }
    
    func stop() {
        let duration = Date().timeIntervalSince1970 - startTime
        let metric = PerformanceMetric(name: name, duration: duration, category: category, metadata: metadata)
        Logger.shared.logPerformance(metric)
    }
}

// MARK: - Global Logging Functions
func logVerbose(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.verbose(message, category: category, file: file, function: function, line: line)
}

func logDebug(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, category: category, file: file, function: function, line: line)
}

func logInfo(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, category: category, file: file, function: function, line: line)
}

func logWarning(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, category: category, file: file, function: function, line: line)
}

func logError(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, category: category, file: file, function: function, line: line)
}

func logError(_ error: Error, context: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.logError(error, context: context, file: file, function: function, line: line)
}

func logCritical(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.critical(message, category: category, file: file, function: function, line: line)
}

func trackEvent(_ name: String, parameters: [String: Any] = [:]) {
    let event = AnalyticsEvent(name: name, parameters: parameters)
    Logger.shared.logEvent(event)
}

func measurePerformance<T>(name: String, category: PerformanceCategory, operation: () throws -> T) rethrows -> T {
    let timer = PerformanceTimer(name: name, category: category)
    let result = try operation()
    timer.stop()
    return result
}

func measurePerformanceAsync<T>(name: String, category: PerformanceCategory, operation: () async throws -> T) async rethrows -> T {
    let timer = PerformanceTimer(name: name, category: category)
    let result = try await operation()
    timer.stop()
    return result
} 