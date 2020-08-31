//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Tracing open source project
//
// Copyright (c) 2020 Moritz Lang and the Swift Tracing project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Baggage
import Instrumentation

/// No operation Tracer, used when no tracing is required.
public struct NoOpTracer: Tracer {
    public func startSpan(
        named operationName: String,
        context: BaggageContextCarrier,
        ofKind kind: SpanKind,
        at timestamp: Timestamp
    ) -> Span {
        return NoOpSpan()
    }

    public func forceFlush() {}

    public func inject<Carrier, Injector>(
        _ context: BaggageContext,
        into carrier: inout Carrier,
        using injector: Injector
    )
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier {}

    public func extract<Carrier, Extractor>(
        _ carrier: Carrier,
        into context: inout BaggageContext,
        using extractor: Extractor
    )
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier {}

    public final class NoOpSpan: Span {
        public var context: BaggageContext {
            return .init()
        }

        public func setStatus(_ status: SpanStatus) {}

        public func addLink(_ link: SpanLink) {}

        public func addEvent(_ event: SpanEvent) {}

        public func recordError(_ error: Error) {}

        public var attributes: SpanAttributes {
            get {
                return [:]
            }
            set {
                // ignore
            }
        }

        public let isRecording = false

        public func end(at timestamp: Timestamp) {
            // ignore
        }
    }
}