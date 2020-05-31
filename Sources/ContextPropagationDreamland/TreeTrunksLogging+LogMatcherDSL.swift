import Logging

//// ==== ----------------------------------------------------------------------------------------------------------------
//// MARK: Log Matcher DSL

extension LogMatcher {

    enum LogMatcherDSLError: Error, CustomStringConvertible {
        case illegal(Substring, at: Substring.Index, reason: String)
        
        var description: String {
            switch self {
            case .illegal(let pattern, let at, let reason):
                return "\(Self.self)(pattern:\(pattern), illegalAt: \(at) (\(pattern[at])), reason: \(reason)"
            }
        }
    }


    /// Examples:
    /// ```
    /// [r=/hello]=debug
    /// ```
    internal static func parse(_ pattern: String) throws -> (Selector, Logger.Level) {
        func parse0(pattern: Substring) throws -> (Selector, Logger.Level) {
            var index = pattern.startIndex

            var selector: Selector
            if pattern[index] == "[" {
                try Self.readSkipChar(pattern, &index, "[")
                let selectors = try Self.readSelectors(pattern, &index)
                selector = selectors.first! // TODO: Allow more of them
                try Self.readSkipChar(pattern, &index, "=")
            } else {
                let label = try Self.readLabel(pattern, &index)
                selector = .labelQuery(label)
                try Self.readSkipChar(pattern, &index, "=")

            }

            let level = try Self.readLogLevel(pattern, &index)

            return (selector, level)
//
//            // TODO; handle quoted names
//            // todo: can be '
//            guard let keyEqualsIndex = pattern.firstIndex(of: "=") else {
//                throw LogMatcherDSLError.illegal(pattern, at: index, reason: "TODO")
//            }
//            let keyEndIndex = pattern.index(before: keyEqualsIndex)
//            // todo: handle `'`
//            let key = String(pattern[index...keyEndIndex]) // TODO: would be nice to allow sub sequences all the way...
//
//            // ='?value'? (until ] OR ,)
//            // todo: handle '
//            let valueStartIndex = pattern.index(after: keyEqualsIndex)
//            let valueEndSeparatorIndex: Substring.Index
//            if let totalEndIndex = pattern[valueStartIndex...].firstIndex(of: "]") {
//                valueEndSeparatorIndex = totalEndIndex
//            } else if let matcherEndIndex = pattern[valueStartIndex...].firstIndex(of: ",") {
//                valueEndSeparatorIndex = matcherEndIndex
//            } else {
//                throw LogMatcherDSLError.illegal(pattern, at: index, reason: "TODO")
//            }
//            // todo: handle end of '
//            let valueEndIndex = pattern[valueStartIndex...].index(before: valueEndSeparatorIndex)
//            let value = String(pattern[valueStartIndex...valueEndIndex])
//
//            // TODO; if last separator was , keep parsing
//            if pattern[valueEndSeparatorIndex] == "," {
//                // keep parsing
//                fatalError("keep parsing not done")
//            } else if pattern[valueEndSeparatorIndex] == "]" {
//                // end of matcher DSL, parse the level
//                let expectedEqualsIndex = pattern.index(after: valueEndSeparatorIndex)
//                guard pattern[expectedEqualsIndex] == "=" else {
//                    throw LogMatcherDSLError.illegal(pattern, at: index, reason: "Missing '='")
//                }
//                var levelStartIndex = pattern.index(after: expectedEqualsIndex)
//                let l = try Self.readLogLevel(pattern, &levelStartIndex)
//                let q = Selector.metadataQuery([key], value) // TODO; more keys
//                return (q, l)
//            }
//
//            throw LogMatcherDSLError.illegal(pattern, at: index, reason: "TODO")
        }

        return try parse0(pattern: pattern[...])
    }


    static func readSelectors(_ pattern: Substring, _ index: inout String.Index) throws -> [Selector] {
        var moreMatchers = true
        var matchers: [Selector] = []

        while moreMatchers {
            let (key, value) = try Self.readSelector(pattern, &index)
            print("key = \(key)")
            print("value = \(value)")
            let keyElements: [String] = key.split(separator: ".").map { String($0) }
            matchers.append(.metadataQuery(keyElements, value))

            switch pattern[index] {
            case ",":
                moreMatchers = true
            case "]":
                moreMatchers = false
                try Self.readSkipChar(pattern, &index, "]")
            case let other:
                throw LogMatcherDSLError.illegal(pattern, at: index, reason: "Expected `,` or `]` but found: '\(other)'")
            }
            if moreMatchers {
                index = pattern.index(after: index)
            }
        }
        if matchers.isEmpty {
            throw LogMatcherDSLError.illegal(pattern, at: index, reason: "No selectors found!")
        }
        return matchers
    }

    /// ```
    /// label=value
    /// 'some label'=value
    /// 'some label'="some value"
    /// ```
    static func readSelector(_ pattern: Substring, _ index: inout String.Index) throws -> (String, String) {
        let label: String
        let value: String
        
        do {
            label = try Self.readLabel(pattern, &index)
        } catch {
            throw LogMatcherDSLError.illegal(pattern, at: index, reason: "Failed parsing label, error: \(error)")
        }
        try Self.readSkipChar(pattern, &index, "=")
        do {
            value = try Self.readValue(pattern, &index)
        } catch {
            throw LogMatcherDSLError.illegal(pattern, at: index, reason: "Failed parsing value, error: \(error)")
        }

        return (label, value)
    }

    static func readLabel(_ pattern: Substring, _ index: inout String.Index) throws -> String {
        if let quote = try Self.tryReadQuote(pattern, &index) {
            return try Self.read(pattern, &index, until: quote)
        } else {
            // not quoted
            return try Self.read(pattern, &index, until: "=")
        }
    }

    static func readValue(_ pattern: Substring, _ index: inout String.Index) throws -> String {
        if let quote = try Self.tryReadQuote(pattern, &index) {
            let value = try Self.read(pattern, &index, until: quote)
            _ = try Self.read(pattern, &index, untilAnyOf: ",]")
            return value
        } else {
            // not quoted
            return try Self.read(pattern, &index, untilAnyOf: ",]")
        }
    }
    static func readSkipChar(_ pattern: Substring, _ index: inout String.Index, _ char: Character) throws {
        if pattern[index] == char {
            index = pattern.index(after: index)
        } else {
            throw LogMatcherDSLError.illegal(pattern, at: index, reason: "Expected '\(char)' but got '\(pattern[index])'")
        }
    }
    static func read(_ pattern: Substring, _ index: inout String.Index, until: Character) throws -> String {
        if let exists = pattern[index...].firstIndex(of: until) {
            guard exists < pattern.endIndex else {
                throw LogMatcherDSLError.illegal(pattern, at: index, reason: "Could not read until next \(until)")
            }
            defer { index = pattern.index(after: exists) }
            print("pattern = \(pattern[index...]) until \(until)")
            let lastIndexOfValue = pattern.index(before: exists)
            guard lastIndexOfValue < pattern.endIndex,
                  index < lastIndexOfValue else {
                throw LogMatcherDSLError.illegal(pattern, at: index, reason: "Illegal range while attempting to read until '\(until)'")
            }
            return "\(pattern[index...lastIndexOfValue])"
        } else {
            throw LogMatcherDSLError.illegal(pattern, at: index, reason: "Wrong field")
        }
    }
    
    static func read(_ pattern: Substring, _ index: inout String.Index, untilAnyOf stopChars: String) throws -> String {
        var stopAt = pattern.endIndex
        
        for stopChar in stopChars {
            if let foundIndex = pattern[index...].firstIndex(of: stopChar) {
                if foundIndex < stopAt {
                stopAt = foundIndex
                }
                break
            } else {
                () // ok, let's try other stopChars
            }
        }
        
        if stopAt != pattern.startIndex {
            defer { index = stopAt }
            return String(pattern[index...pattern.index(before: stopAt)])
        } else {
            throw LogMatcherDSLError.illegal(pattern, at: index, reason: "can't read untilAnyOf \(stopChars)")
        }
    }

    static func tryReadQuote(_ pattern: Substring, _ index: inout String.Index) throws -> Character? {
        guard index < pattern.endIndex else {
            throw LogMatcherDSLError.illegal(pattern, at: pattern.endIndex, reason: "Attempt to read quote past last index")
        }
        
        let char = pattern[index]
        switch char {
        case "\"":
            index = pattern.index(after: index)
            return char
        case "'":
            index = pattern.index(after: index)
            return char
        default:
            return nil
        }
    }

    internal static func readLogLevel(_ pattern: Substring, _ index: inout Substring.Index) throws -> Logger.Level {
        guard index < pattern.endIndex else {
            throw  LogMatcherDSLError.illegal(pattern, at: pattern.endIndex, reason: "Attempt to parse past end of pattern")
        }
        
        if pattern[index...].count == 1 {
            switch pattern[index] {
            case "t":
                index = pattern.index(after: index)
                return .trace
            case "d":
                index = pattern.index(after: index)
                return .debug
            case "i":
                index = pattern.index(after: index)
                return .info
            case "n":
                index = pattern.index(after: index)
                return .notice
            case "w":
                index = pattern.index(after: index)
                return .warning
            case "e":
                index = pattern.index(after: index)
                return .error
            case "c":
                index = pattern.index(after: index)
                return .critical
            default:
                throw LogMatcherDSLError.illegal(pattern, at: index, reason: "illegal log level: \(pattern[index...])") // illegal level (!)
            }
        } else {
            switch pattern[index] {
            case "t":
                try Self.readExpected(pattern, &index, expect: "trace")
                return .trace
            case "d":
                try Self.readExpected(pattern, &index, expect: "debug")
                return .debug
            case "i":
                try Self.readExpected(pattern, &index, expect: "info")
                return .info
            case "n":
                try Self.readExpected(pattern, &index, expect: "notice")
                return .notice
            case "w":
                try Self.readExpected(pattern, &index, expect: "warning")
                return .warning
            case "e":
                try Self.readExpected(pattern, &index, expect: "error")
                return .error
            case "c":
                try Self.readExpected(pattern, &index, expect: "critical")
                return .critical
            default:
                throw LogMatcherDSLError.illegal(pattern, at: index, reason: "illegal log level: \(pattern[index...])") // illegal level (!)
            }
        }
    }
    
    static func readExpected(_ pattern: Substring, _ index: inout Substring.Index, expect: String) throws {
        guard index < pattern.endIndex else {
            throw LogMatcherDSLError.illegal(pattern, at: pattern.endIndex, reason: "Attempted to read expected '\(expect)' past end of pattern")
        }
        guard pattern[index...].count == expect.count else {
            throw LogMatcherDSLError.illegal(pattern, at: index, reason: "Expected '\(expect)' but remaining chars in pattern cannot fulfil the match: '\(pattern[index...])'")
        }
        
        
    }

}
