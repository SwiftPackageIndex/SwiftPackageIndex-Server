// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import NIO


extension Array {

    /// Map `Result<T, E>` elements with the given `transform` to `EventLoopFuture<U>`by transforming the sucess case and passing through the error `E` in case of failures.
    /// - Parameters:
    ///   - eventLoop: event loop
    ///   - transform: transformation
    /// - Returns: array of futures
    func map<T, U, E>(on eventLoop: EventLoop,
                      transform: (T) -> EventLoopFuture<U>) -> [EventLoopFuture<U>] where Element == Result<T, E> {
        map { result in
            switch result {
                case .success(let v): return transform(v)
                case .failure(let e): return eventLoop.future(error: e)
            }
        }
    }

    /// Returns a new `EventLoopFuture` that succeeds when all `Result<T, Error>` elements transformed into `EventLoopFuture<U>` elements have completed.
    /// - Parameters:
    ///   - eventLoop: The `EventLoop` on which the new `EventLoopFuture` callbacks will fire.
    ///   - transform: The transformation to be applied to the `Array`'s elements
    /// - Returns: A new `Array` with the results of the transformation, wrapped in `Result`s.
    func whenAllComplete<T, U>(on eventLoop: EventLoop,
                               transform: (T) -> EventLoopFuture<U>) -> EventLoopFuture<[Result<U, Error>]> where Element == Result<T, Error> {
        EventLoopFuture.whenAllComplete(
            map(on: eventLoop, transform: transform),
            on: eventLoop
        )
    }

}
