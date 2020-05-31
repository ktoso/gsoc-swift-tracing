import Logging

//// ==== ----------------------------------------------------------------------------------------------------------------
//// MARK: Log Matcher DSL

extension LogMatcher {

    enum LogMatcherDSLError: Error {
        case illegal(Substring, reason: String)
    }


    /// Examples:
    /// ```
    /// [r=/hello]=debug
    /// ```
    internal static func parse(_ pattern: String) throws -> (Selector, Logger.Level)? {
        func parse0(pattern: inout Substring) throws -> (Selector, Logger.Level)? {
            var selector: Selector
            switch pattern.first {
            case "[":
                try Self.readSkipChar(&pattern, "[")
                let selectors = try Self.readSelectors(&pattern)
                try Self.readSkipChar(&pattern, "]")
                
                // are we the special `[]=` "reset" pattern?
                if selectors.isEmpty {
                    try Self.readExpected(&pattern, expect: "=")
                    if pattern.isEmpty {
                        return nil
                    } else {
                        throw LogMatcherDSLError.illegal(pattern, reason: "No selectors found in pattern!")
                    }
                }
                selector = selectors.first! // TODO: Allow more of them

            default:
                let label = try Self.readLabel(&pattern)
                selector = .labelQuery(label)
            }

            try Self.readSkipChar(&pattern, "=")
            let level = try Self.readLogLevel(&pattern)

            return (selector, level)
        }

        guard pattern != "[]=" else {
            // "reset" pattern
            return nil
        }
        
        var patternSubstring = pattern[...]
        return try parse0(pattern: &patternSubstring)
    }


    static func readSelectors(_ pattern: inout Substring) throws -> [Selector] {
        var moreSelectors = true
        var matchers: [Selector] = []

        while moreSelectors {
            let (key, value) = try Self.readSelector(&pattern)
            guard key != "" else {
                throw LogMatcherDSLError.illegal(pattern, reason: "Empty key in selector! Key: \(key), value: \(value)")
            }
            guard value != "" else {
                throw LogMatcherDSLError.illegal(pattern, reason: "Empty value in selector! Key: \(key), value: \(value)")
            }
            // each selector key is a "path" separated by `.`, those are used to index into the metadata dictionary
            let keyElements: [String] = key.split(separator: ".").map { String($0) }
            matchers.append(.metadataQuery(keyElements, value))

            switch pattern.first {
            case ",":
                moreSelectors = true
                try Self.readSkipChar(&pattern, ",")
            case "]":
                moreSelectors = false
            case let other:
                throw LogMatcherDSLError.illegal(pattern, reason: "Expected ',' or ']' but found: '\(String(reflecting: other))'")
            }
        }
        if matchers.isEmpty {
            throw LogMatcherDSLError.illegal(pattern, reason: "No selectors found!")
        }
        return matchers
    }

    /// ```
    /// label=value
    /// 'some label'=value
    /// 'some label'="some value"
    /// ```
    static func readSelector(_ pattern: inout Substring) throws -> (String, String) {
        let label: String
        let value: String

        do {
            label = try Self.readLabel(&pattern)
        } catch {
            throw LogMatcherDSLError.illegal(pattern, reason: "Failed parsing label, error: \(error)")
        }
        try Self.readSkipChar(&pattern, "=")
        do {
            value = try Self.readValue(&pattern)
        } catch {
            throw LogMatcherDSLError.illegal(pattern, reason: "Failed parsing value, error: \(error)")
        }

        return (label, value)
    }

    static func readLabel(_ pattern: inout Substring) throws -> String {
        if let quote = try Self.tryReadQuote(&pattern) {
            let label = try Self.read(&pattern, until: quote)
            try Self.readSkipChar(&pattern, quote)
            return label
        } else {
            // not quoted
            return try Self.read(&pattern, until: "=")
        }
    }

    static func readValue(_ pattern: inout Substring) throws -> String {
        if let quote = try Self.tryReadQuote(&pattern) {
            let value = try Self.read(&pattern, until: quote)
            _ = try Self.read(&pattern, untilAnyOf: ",]") // drop the , or ] // TODO likely wrong for lists
            return value
        } else {
            // not quoted
            return try Self.read(&pattern, untilAnyOf: ",]")
        }
    }

    static func readSkipChar(_ pattern: inout Substring, _ char: Character) throws {
        if pattern.first == char {
            pattern = pattern.dropFirst()
        } else {
            throw LogMatcherDSLError.illegal(pattern, reason: "Expected '\(char)' but got '\(String(reflecting: pattern.first))'")
        }
    }

    static func read(_ pattern: inout Substring, until: Character) throws -> String {
        if let exists = pattern.firstIndex(of: until) {
            guard exists < pattern.endIndex else {
                throw LogMatcherDSLError.illegal(pattern, reason: "Could not read until next \(until)")
            }
            defer { pattern = pattern[exists...] }
            // TODO range error handling
            return "\(pattern[..<exists])"
        } else {
            throw LogMatcherDSLError.illegal(pattern, reason: "Wrong field")
        }
    }

    /// Does NOT consume the stop character.
    static func read(_ pattern: inout Substring, untilAnyOf stopChars: String) throws -> String {
        var stopAt = pattern.endIndex

        for stopChar in stopChars {
            if let foundIndex = pattern.firstIndex(of: stopChar) {
                if foundIndex < stopAt {
                    stopAt = foundIndex
                }
                break
            } else {
                () // ok, let's try other stopChars
            }
        }

        if stopAt != pattern.startIndex && stopAt != pattern.endIndex {
            defer {
                pattern = pattern[stopAt...] // FIXME range check
            }
            return String(pattern[...pattern.index(before: stopAt)])
        } else {
            throw LogMatcherDSLError.illegal(pattern, reason: "can't read untilAnyOf \(stopChars)")
        }
    }

    static func tryReadQuote(_ pattern: inout Substring) throws -> Character? {
        guard let char = pattern.first else {
           return nil
        }

        switch char {
        case "\"":
            pattern = pattern.dropFirst()
            return char
        case "'":
            pattern = pattern.dropFirst()
            return char
        default:
            return nil
        }
    }

    internal static func readLogLevel(_ pattern: inout Substring) throws -> Logger.Level {
        if pattern.count == 1 {
            switch pattern.first {
            case "t":
                pattern = pattern.dropFirst()
                return .trace
            case "d":
                pattern = pattern.dropFirst()
                return .debug
            case "i":
                pattern = pattern.dropFirst()
                return .info
            case "n":
                pattern = pattern.dropFirst()
                return .notice
            case "w":
                pattern = pattern.dropFirst()
                return .warning
            case "e":
                pattern = pattern.dropFirst()
                return .error
            case "c":
                pattern = pattern.dropFirst()
                return .critical
            default:
                throw LogMatcherDSLError.illegal(pattern, reason: "Unexpected log level")
            }
        } else {
            switch pattern.first {
            case "t":
                try Self.readExpected(&pattern, expect: "trace")
                return .trace
            case "d":
                try Self.readExpected(&pattern, expect: "debug")
                return .debug
            case "i":
                try Self.readExpected(&pattern, expect: "info")
                return .info
            case "n":
                try Self.readExpected(&pattern, expect: "notice")
                return .notice
            case "w":
                try Self.readExpected(&pattern, expect: "warning")
                return .warning
            case "e":
                try Self.readExpected(&pattern, expect: "error")
                return .error
            case "c":
                try Self.readExpected(&pattern, expect: "critical")
                return .critical
            default:
                throw LogMatcherDSLError.illegal(pattern, reason: "illegal log level: \(pattern)") // illegal level
            }
        }
    }

    static func readExpected(_ pattern: inout Substring, expect: String) throws {
        guard pattern.count == expect.count else {
            throw LogMatcherDSLError.illegal(pattern, reason: "Expected '\(expect)' but remaining chars in pattern cannot fulfil the match")
        }

        if pattern.starts(with: expect) {
            pattern = pattern.dropFirst(expect.count)
            return // ok!
        } else {
            throw LogMatcherDSLError.illegal(pattern, reason: "Expected to read '\(expect)' but got: \(pattern)")
        }

    }

}
