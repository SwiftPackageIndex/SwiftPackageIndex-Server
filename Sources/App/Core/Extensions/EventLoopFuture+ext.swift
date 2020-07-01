import NIO


#if DEBUG
extension EventLoopFuture {
    static func just<T>(value: T) -> EventLoopFuture<T> {
        EmbeddedEventLoop().future(value)
    }
    
    static func just<T, E: Error>(error: E) -> EventLoopFuture<T> {
        EmbeddedEventLoop().makeFailedFuture(error)
    }
}
#endif
