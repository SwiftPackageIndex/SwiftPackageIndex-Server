import NIO


extension Array {
    func whenAllComplete<T>(on eventLoop: EventLoop,
                            transform: (T) -> EventLoopFuture<T>) -> EventLoopFuture<[Result<T, Error>]>
    where Element == Result<T, Error> {
        let ops = map { result -> EventLoopFuture<T> in
            switch result {
                case let .success(value):
                    return transform(value)
                case let .failure(error):
                    return eventLoop.future(error: error)
            }
        }
        return EventLoopFuture.whenAllComplete(ops, on: eventLoop)
    }
}
