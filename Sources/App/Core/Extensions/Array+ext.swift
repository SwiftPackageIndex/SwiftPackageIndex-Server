import NIO


extension Array {
    func whenAllComplete<T, U>(on eventLoop: EventLoop,
                               transform: (T) -> EventLoopFuture<U>) -> EventLoopFuture<[Result<U, Error>]>
    where Element == Result<T, Error> {
        let ops = map { result -> EventLoopFuture<U> in
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
