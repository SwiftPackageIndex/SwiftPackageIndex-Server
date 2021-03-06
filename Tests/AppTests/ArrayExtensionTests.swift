// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

@testable import App
import NIO
import XCTest


class ArrayExtensionTests: XCTestCase {

    func test_map_Result_to_EventLoopFuture() throws {
        // setup
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let results = [0, 1, 2].map { Result<Int, Error>.success($0) }

        // MUT
        let mapped = results.map(on: elg.next()) {
            elg.future(String($0))
        }

        // validate
        let res = try mapped.flatten(on: elg.next()).wait()
        XCTAssertEqual(res, ["0", "1", "2"])
    }

    func test_map_Result_to_EventLoopFuture_with_errors() throws {
        // setup
        enum MyError: Error, Equatable { case failed }
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let results: [Result<Int, MyError>] = [
            .success(0),
            .failure(MyError.failed),
            .success(2)
        ]

        // MUT
        let mapped = results.map(on: elg.next()) {
            elg.future(String($0))
        }

        // validate
        XCTAssertEqual(try mapped[0].wait(), "0")
        XCTAssertThrowsError(try mapped[1].wait()) {
            XCTAssertEqual($0 as? MyError, MyError.failed)
        }
        XCTAssertEqual(try mapped[2].wait(), "2")
    }

    func test_whenAllComplete() throws {
        // setup
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let results = [0, 1, 2].map { Result<Int, Error>.success($0) }

        // MUT
        let res = try results.whenAllComplete(on: elg.next()) {
            elg.future(String($0))
        }.wait()

        // validate
        XCTAssertEqual(res.compactMap { try? $0.get() }, ["0", "1", "2"])
    }

    func test_whenAllComplete_with_errors() throws {
        // setup
        enum MyError: Error { case failed }
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let results: [Result<Int, Error>] = [
            .success(0),
            .failure(MyError.failed),
            .success(2)
        ]

        // MUT
        let res = try results.whenAllComplete(on: elg.next()) {
            elg.future(String($0))
        }.wait()

        // validate
        XCTAssertEqual(res.compactMap { try? $0.get() }, ["0", "2"])
    }

}
