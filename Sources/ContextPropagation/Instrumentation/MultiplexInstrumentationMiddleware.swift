public struct MultiplexInstrumentationMiddleware<InjectInto, ExtractFrom> {
    private var middleware: [InstrumentationMiddleware<InjectInto, ExtractFrom>]

    public init(_ middleware: [InstrumentationMiddleware<InjectInto, ExtractFrom>]) {
        self.middleware = middleware
    }
}

extension MultiplexInstrumentationMiddleware: InstrumentationMiddlewareProtocol {
    public func extract(from: ExtractFrom, into context: inout Context) {
        middleware.forEach { $0.extract(from: from, into: &context) }
    }

    public func inject(from context: Context, into: inout InjectInto) {
        middleware.forEach { $0.inject(from: context, into: &into) }
    }
}
