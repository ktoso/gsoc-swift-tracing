import ContextPropagation

struct B3Tracer {
    typealias From = [String: String]
    typealias To = [String: String] // TODO: would be some http header thingy

    static let traceID: String = "X-B3-TraceId"
    static let parentSpanID: String = "X-B3-ParentSpanID"
    static let spanID: String = "X-B3-SpanID"
    static let sampled: String = "X-B3-Sampled"

    enum Keys {
        enum TraceID: ContextKey {
            typealias Value = String
        }
        enum ParentSpanID: ContextKey {
            typealias Value = String
        }
        enum SpanID: ContextKey {
            typealias Value = String
        }
        enum Sampled: ContextKey {
            typealias Value = Int
        }
    }

    func inject(context: Context, to carrier: inout To) {
        if let traceID = context.extract(Keys.TraceID.self) {
            carrier[Self.traceID] = traceID
        }
        if let parentSpanID = context.extract(Keys.ParentSpanID.self) {
            carrier[Self.parentSpanID] = parentSpanID
        }
        if let spanID = context.extract(Keys.SpanID.self) {
            carrier[Self.spanID] = spanID
        }
        if let sampled = context.extract(Keys.Sampled.self) {
            carrier[Self.sampled] = "\(sampled)"
        }
    }

    func extract(from carrier: From, into context: inout Context) {
//        if let traceID = carrier[Self.traceID] {
//            context.inject(<#T##key: Key.Type##Key.Type#>, value: <#T##Key.Value##Key.Value#>)
//        }
    }


}