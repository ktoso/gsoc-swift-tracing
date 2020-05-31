import ContextPropagation
import ContextPropagationDreamland
import XCTest
import Logging

final class TreeTrunksLoggingTests: XCTestCase {
    func test_LogMatcher_parsing_metadataQuery_reset() throws {
        try assertPattern(
            pattern: "[]=", // exactly the reset pattern
            query: nil,
            level: nil
        )
        assertThrows(
            pattern: "[]=debug" // not exactly the reset pattern
        )
    }
    
    func test_LogMatcher_parsing_metadataQuery() throws {
        try assertPattern(
            pattern: "[x=hello]=debug",
            query: .metadataQuery(["x"], "hello"),
            level: .debug
        )
        try assertPattern(
            pattern: "[x.nested.key=hello]=debug",
            query: .metadataQuery(["x", "nested", "key"], "hello"),
            level: .debug
        )
        try assertPattern(
            pattern: "[x=hello]=d", // shorthand ok
            query: .metadataQuery(["x"], "hello"),
            level: .debug
        )
    }
    
    func test_LogMatcher_parsing_metadataQuery_quoted() throws {
        try assertPattern(
            pattern: "['some key'=hello]=debug",
            query: .metadataQuery(["some key"], "hello"),
            level: .debug
        )
        try assertPattern(
            pattern: "[\"some key\"=hello]=debug",
            query: .metadataQuery(["some key"], "hello"),
            level: .debug
        )

        try assertPattern(
            pattern: "[key=\"hello world\"]=debug",
            query: .metadataQuery(["key"], "hello world"),
            level: .debug
        )
        try assertPattern(
            pattern: "[\"some key\"=\"hello\"]=debug",
            query: .metadataQuery(["some key"], "hello"),
            level: .debug
        )
    }
    
    func test_LogMatcher_parsing_labelQuery() throws {
        try assertPattern(
            pattern: "label=debug", // shorthand ok
            query: .labelQuery("label"),
            level: .debug
        )
    }

    func test_LogMatcher_parsing_metadataQuery_bad() throws {
        assertThrows(pattern: "[]=debug") // no selectors
        // TODO: special case []= as "reset"
        
        assertThrows(pattern: "[x=hello]=") // missing level
        assertThrows(pattern: "[x=hello]=nein") // weird level

        assertThrows(pattern: "[=hello]=debug") // empty matcher
        assertThrows(pattern: "[x=hello,=hello2]=debug") // empty 2nd matcher
    }

    @discardableResult
    private func assertThrows(pattern: String) -> Error? {
        do {
            print("  Test pattern: \(pattern)")
            let x = try LogMatcher(pattern: pattern)
            let message = "Expected throw, got: \(x)"
            XCTFail(message)
            return nil
        } catch {
            return error
        }
    }

    private func assertPattern(pattern: String, query: LogMatcher.Selector?, level: Logger.Level?) throws {
        print("  Test pattern: \(pattern)")
        if let matcher = try ContextPropagationDreamland.LogMatcher(pattern: pattern) {
            XCTAssertEqual(matcher.query, query)
            XCTAssertEqual(matcher.level, level)
        } else {
            XCTAssertEqual(nil, query)
            XCTAssertEqual(nil, level)
        }
    }
}

private enum TestTraceIDKey: ContextKey {
    typealias Value = UUID
}
