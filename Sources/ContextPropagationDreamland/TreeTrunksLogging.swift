import Logging
import class Foundation.NSLock

public final class TreeTrunksLogging: LogHandler {

    let lock: NSLock
    var _logMatcher: LogMatcher?
    var logMatcher: LogMatcher? {
        get {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self._logMatcher
        }
        set {
            self.lock.lock()
            defer { self.lock.unlock() }
            self._logMatcher = newValue
        }
    }

    let baseLogLevel: Logger.Level

    let underlying: LogHandler

    public init(wrap logHandler: LogHandler) {
        self.lock = NSLock()
        self._logMatcher = nil
        self.underlying = logHandler
        var l = logHandler
        self.baseLogLevel = logHandler.logLevel
        self.logLevel = .info
        l.logLevel = .trace
    }

    public func configure(matcher: LogMatcher?) {
        self.logMatcher = matcher
    }

    public func configure(_ pattern: String) throws {
        self.logMatcher = try LogMatcher(pattern: pattern)
    }

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        file: String, function: String, line: UInt
    ) {
        guard let matcher = self.logMatcher else {
            if self.baseLogLevel <= level {
                // pass through
                self.underlying
                    .log(level: level, message: message, metadata: metadata, file: file, function: function, line: line)
            } // else, ignore
            return
        }

        guard let matcherSelectedLevel = matcher.match(message: message, metadata: metadata) else {
            if self.baseLogLevel <= level {
                self.underlying
                    .log(level: level, message: message, metadata: metadata, file: file, function: function, line: line)
            } // else, ignore
            return
        }

        self.underlying
            .log(level: matcherSelectedLevel, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    public subscript(metadataKey _: String) -> Logger.Metadata.Value? { // FIXME wat!!!! why the `_`
        get {
            fatalError("subscript(metadataKey:) has not been implemented")
        }
        set {
        }
    }
    public var metadata: Logger.Metadata = [:]
    public var logLevel: Logger.Level
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Log Matcher

public struct LogMatcher {
     public typealias MetadataQueryPath = [String]

    public enum Selector: Equatable {
        case labelQuery(String)
        case metadataQuery(MetadataQueryPath, String)
    }

    public let query: Selector
    public let level: Logger.Level

    public init?(pattern: String) throws {
        if let (query, level) = try Self.parse(pattern) {
            self.query = query
            self.level = level
        } else {
            return nil
        }
    }

    public init(_ query: Selector, level: Logger.Level) {
        self.query = query
        self.level = level
    }

    func match(message: Logger.Message, metadata: Logger.Metadata?) -> Logger.Level? {
        switch self.query {
        case .labelQuery(let label):
            return self.matchLabel(label: label, message: message, metadata: metadata)
        case .metadataQuery(let path, let value):
            return self.matchMetadata(path: path[...], expected: value, metadata: metadata)
        }
    }

    private func matchLabel(label: String, message: Logger.Message, metadata: Logger.Metadata?) -> Logger.Level? {
        fatalError("matchLabel(label:message:metadata:) has not been implemented")
    }

    private func matchMetadata(path: ArraySlice<String>, expected: String, metadata: Logger.Metadata?) -> Logger.Level? {
        func matchMetadata0(path: ArraySlice<String>, expected: String, metadata: Logger.Metadata) -> Logger.Level? {
            guard let key = path.first else {
                return nil
            }
            guard let value = metadata[key] else {
                return nil
            }

            if path.count == 1 {
                // this is it, match it
                // TODO: better regex matchers etc
                if "\(value)" == value {
                    return self.level
                } else {
                    return nil
                }
            } else {
                // "we need to go deeper"
                // only id this value is a dictionary we can do so
                switch value {
                case .dictionary(let nestedMetadata):
                    return self.matchMetadata(path: path.dropFirst(), expected: expected, metadata: nestedMetadata)
                default:
                    return nil
                }
            }
        }

        guard let metadata = metadata else {
            return nil
        }

        return matchMetadata0(path: path, expected: expected, metadata: metadata)
    }

}
