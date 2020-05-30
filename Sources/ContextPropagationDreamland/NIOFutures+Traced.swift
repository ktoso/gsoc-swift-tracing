//
//// ==== ----------------------------------------------------------------------------------------------------------------
//// MARK: swift-nio-baggage
//
//func main(loop: EventLoop) {
//    let baggage = Context()
//
//    let promise = loop.carry(baggage).makePromise(of: String.self)
//
//    let promise = loop.carry(.localBaggage).makePromise(of: String.self)
//}
//
//protocol BaggageCarrying {
//
//}
//
//extension EventLoop: BaggageCarrying {
//  func carry
//}
//
//
//// ==== ----------------------------------------------------------------------------------------------------------------
//// MARK: NIO
//
//struct EventLoop {
//    func makePromise<T>(of: T.Type = T.self) -> EventLoopPromise<T> {
//        fatalError()
//    }
//}
//
//struct EventLoopPromise<T> {
//    let futureResult: EventLoopFuture<T>
//}
//struct EventLoopFuture<T> {
//
//}
