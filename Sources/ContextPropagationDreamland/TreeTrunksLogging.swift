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

    let underlying: LogHandler
    public var logLevel: Logger.Level {
        get {
            .trace
        }
        set {
            // ignore
        }
    }
    let passThroughLogLevel: Logger.Level
    

    public init(wrap logHandler: LogHandler) {
        self.lock = NSLock()
        self._logMatcher = nil
        
        
        var l = logHandler
        l.logLevel = .trace // if we decide it should log, it should do so
        self.underlying = l
        
        self.passThroughLogLevel = logHandler.logLevel
        
    }

    public func configure(matcher: LogMatcher) {
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
        if let matcher = self.logMatcher,
           let matchedAsLevel = matcher.match(message: message, metadata: metadata) {
            // matcher decided we should lot it on specific level
            self.underlying
                .log(level: matchedAsLevel, message: message, metadata: metadata, file: file, function: function, line: line)
        } else if self.logLevel <= level {
            // pass through as-is
            self.underlying
                .log(level: level, message: message, metadata: metadata, file: file, function: function, line: line)
        } // else, ignore
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? { // FIXME wat!!!! why the `_`
        get {
            fatalError("subscript(metadataKey:\(key) has not been implemented")
        }
        set {
        }
    }
    public var metadata: Logger.Metadata = [:]

}

public struct LogMatcher {

    public enum Query: Equatable {
        case messageContains(String)
        case messagePrefix(String)
        case metadataQuery(MetadataQueryPath, String)
    }

    public typealias MetadataQueryPath = [String]

    let query: Query
    let level: Logger.Level


    public init(pattern: String) throws {
        let (q, l) = try Self.parse(pattern)
        self.query = q
        self.level = l
    }

    enum QueryPatternError: Error {
        case illegal
    }

    /// Examples:
    /// ```
    /// [r=/hello]=debug
    /// ```
    internal static func parse(_ pattern: String) throws -> (Query, Logger.Level) {
        func parse0(pattern: String.SubSequence) throws -> (Query, Logger.Level) {
            var atIdx = pattern.startIndex
            guard pattern[atIdx] == "[" else {
                throw QueryPatternError.illegal
            }
            atIdx = pattern.index(after: atIdx)

            // TODO; handle quoted names
            // todo: can be '
            guard let keyEqualsIndex = pattern.firstIndex(of: "=") else {
                throw QueryPatternError.illegal
            }
            let keyEndIndex = pattern.index(before: keyEqualsIndex)
            // todo: handle `'`
            let key = String(pattern[atIdx...keyEndIndex]) // TODO: would be nice to allow sub sequences all the way...

            // ='?value'? (until ] OR ,)
            // todo: handle '
            let valueStartIndex = pattern.index(after: keyEqualsIndex)
            let valueEndSeparatorIndex: String.SubSequence.Index
            if let totalEndIndex = pattern[valueStartIndex...].firstIndex(of: "]") {
                valueEndSeparatorIndex = totalEndIndex
            } else if let matcherEndIndex = pattern[valueStartIndex...].firstIndex(of: ",") {
                valueEndSeparatorIndex = matcherEndIndex
            } else {
                throw QueryPatternError.illegal
            }
            // todo: handle end of '
            let valueEndIndex = pattern[valueStartIndex...].index(before: valueEndSeparatorIndex)
            let value = String(pattern[valueStartIndex...valueEndIndex])

            // TODO; if last separator was , keep parsing
            if pattern[valueEndSeparatorIndex] == "," {
                // keep parsing
                fatalError("keep parsing not done")
            } else if pattern[valueEndSeparatorIndex] == "]" {
                // end of matcher DSL, parse the level
                let l: Logger.Level
                let expectedEqualsIndex = pattern.index(after: valueEndSeparatorIndex)
                guard pattern[expectedEqualsIndex] == "=" else {
                    throw QueryPatternError.illegal // missing =
                }
                switch pattern[pattern.index(after: expectedEqualsIndex)] {
                case "t":
                    l = .trace
                case "d":
                    l = .debug
                case "i":
                    l = .info
                case "n":
                    l = .notice
                case "w":
                    l = .warning
                case "e":
                    l = .error
                case "c":
                    l = .critical
                default:
                    throw QueryPatternError.illegal // illegal level (!)
                }
                let q = Query.metadataQuery([key], value) // TODO; more keys
                return (q, l)
            }

            throw QueryPatternError.illegal // todo: reason?
        }

        return try parse0(pattern: pattern[...])
    }

    public init(_ query: Query, level: Logger.Level) {
        self.query = query
        self.level = level
    }

    func match(message: Logger.Message, metadata: Logger.Metadata?) -> Logger.Level? {
        switch self.query {
        case .messageContains(let string):
            return self.matchMessage(contains: string, message: message, metadata: metadata)
        case .messagePrefix(let string):
            return self.matchMessage(prefix: string, message: message, metadata: metadata)
        case .metadataQuery(let path, let value):
            return self.matchMetadata(path: path[...], expected: value, metadata: metadata)
        }
    }

    private func matchMessage(contains: String, message: Logger.Message, metadata: Logger.Metadata?) -> Logger.Level? {
        fatalError("matchMessage(contains:message:metadata:) has not been implemented")
    }

    private func matchMessage(prefix: String, message: Logger.Message, metadata: Logger.Metadata?) -> Logger.Level? {
        fatalError("matchMessage(prefix:message:metadata:) has not been implemented")
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