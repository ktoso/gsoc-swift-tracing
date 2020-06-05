public struct MultiplexInstrumentationMiddleware<InjectInto, ExtractFrom> {
    private var middlewares: [InstrumentationMiddleware<InjectInto, ExtractFrom>]

    public init<Middleware>(_ middlewares: [Middleware])
        where
        Middleware: InstrumentationMiddlewareProtocol,
        Middleware.InjectInto == InjectInto,
        Middleware.ExtractFrom == ExtractFrom {
        self.middlewares = middlewares.map(InstrumentationMiddleware.init)
    }
}

extension MultiplexInstrumentationMiddleware: InstrumentationMiddlewareProtocol {
    public func extract(from: ExtractFrom, into context: inout Context) {
        middlewares.forEach { $0.extract(from: from, into: &context) }
    }

    public func inject(from context: Context, into: inout InjectInto) {
        middlewares.forEach { $0.inject(from: context, into: &into) }
    }
}
