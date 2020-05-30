import ContextPropagation
@testable import ContextPropagationDreamland
import XCTest
import Logging

final class TreeTrunksLoggingTests: XCTestCase {
    func test_LogMatcher_parsing() throws {
        try assertPattern(
            pattern: "[x=hello]=debug", 
            query: LogMatcher.Query.metadataQuery(["x"], "hello"),
            level: .debug
        )
    }

    private func assertPattern(pattern: String, query q: LogMatcher.Query, level l: Logger.Level) throws {
        let (q, l) = try LogMatcher.parse(pattern)
        XCTAssertEqual(q, LogMatcher.Query.metadataQuery(["x"], "hello"))
        XCTAssertEqual(l, Logger.Level.debug)
    }
}

private enum TestTraceIDKey: ContextKey {
    typealias Value = UUID
}
