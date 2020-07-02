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

import AsyncHTTPClient
import Baggage
import BaggageLogging
import Instrumentation
import NIO
import NIOHTTP1
import NIOInstrumentation

struct InstrumentedHTTPClient {
    private let client: HTTPClient
    private let instrument: Instrument

    init(instrument: Instrument, eventLoopGroupProvider: HTTPClient.EventLoopGroupProvider) {
        self.client = HTTPClient(eventLoopGroupProvider: eventLoopGroupProvider)
        self.instrument = instrument
    }

    // TODO: deadline: NIODeadline? would move into baggage?
    public func get(url: String, baggage: BaggageContext = .init()) -> EventLoopFuture<HTTPClient.Response> {
        do {
            let request = try HTTPClient.Request(url: url, method: .GET)
            return self.execute(request: request, baggage: baggage)
        } catch {
            return self.client.eventLoopGroup.next().makeFailedFuture(error)
        }
    }

    func execute(request: HTTPClient.Request, baggage: BaggageContext) -> EventLoopFuture<HTTPClient.Response> {
        var request = request
        self.instrument.inject(baggage, into: &request.headers, using: HTTPHeadersInjector())
        baggage.logger.info("🌎 InstrumentedHTTPClient: Execute request")
        return self.client.execute(request: request)
    }

    func syncShutdown() throws {
        try self.client.syncShutdown()
    }
}
