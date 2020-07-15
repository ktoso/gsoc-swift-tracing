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
import Dispatch

/// No operation TracingInstrument, used when no tracing is required.
public struct NoOpTracingInstrument: TracingInstrument {
    public var currentSpan: Span? = nil

    public func startSpan(
        named operationName: String,
        context: BaggageContext,
        ofKind kind: SpanKind,
        at timestamp: DispatchTime?
    ) -> Span {
        NoOpSpan()
    }

    public func inject<Carrier, Injector>(_ context: BaggageContext, into carrier: inout Carrier, using injector: Injector)
        where
        Injector: InjectorProtocol,
        Carrier == Injector.Carrier {}

    public func extract<Carrier, Extractor>(_ carrier: Carrier, into baggage: inout BaggageContext, using extractor: Extractor)
        where
        Extractor: ExtractorProtocol,
        Carrier == Extractor.Carrier {}

    public struct NoOpSpan: Span {
        public var operationName: String = ""
        public var status: SpanStatus?
        public let kind: SpanKind = .internal

        public var startTimestamp: DispatchTime {
            .now()
        }

        public var endTimestamp: DispatchTime? = nil

        public var baggage: BaggageContext {
            .init()
        }

        public var events: [SpanEvent] {
            []
        }

        public mutating func addEvent(_ event: SpanEvent) {}

        public var attributes: SpanAttributes {
            get {
                [:]
            }
            set {
                // ignore
            }
        }

        public let isRecording = false

        public mutating func end(at timestamp: DispatchTime) {
            // ignore
        }
    }
}