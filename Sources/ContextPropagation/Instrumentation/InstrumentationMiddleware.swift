public protocol InstrumentationMiddlewareProtocol {
    associatedtype ExtractFrom
    associatedtype InjectInto

    func extract(from: ExtractFrom, into context: inout Context)
    func inject(from context: Context, into: inout InjectInto)
}

public struct InstrumentationMiddleware<InjectInto, ExtractFrom>: InstrumentationMiddlewareProtocol {
    private let _extract: (ExtractFrom, inout Context) -> Void
    private let _inject: (Context, inout InjectInto) -> Void

    public init<Middleware>(_ middleware: Middleware)
        where
        Middleware: InstrumentationMiddlewareProtocol,
        Middleware.ExtractFrom == Self.ExtractFrom,
        Middleware.InjectInto == Self.InjectInto {
        if let alreadyWrapped = middleware as? InstrumentationMiddleware<InjectInto, ExtractFrom> {
            self = alreadyWrapped
        } else {
            _extract = { from, context in middleware.extract(from: from, into: &context) }
            _inject = { context, into in middleware.inject(from: context, into: &into) }
        }
    }

    public func extract(from: ExtractFrom, into context: inout Context) {
        _extract(from, &context)
    }

    public func inject(from context: Context, into: inout InjectInto) {
        _inject(context, &into)
    }
}
