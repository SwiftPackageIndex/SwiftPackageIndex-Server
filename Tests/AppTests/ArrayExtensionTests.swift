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

import XCTest

@testable import App

import NIO
import SPIManifest


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

    func test_defaultBranchVersion() throws {
        XCTAssertEqual(
            [
                Version(id: .id0, latest: .release),
                Version(id: .id1, latest: .defaultBranch)
            ].defaultBranchVersion?.id,
            .id1
        )
        XCTAssertEqual(
            [
                Version(id: .id0, latest: .release),
                Version(id: .id1, latest: .preRelease),
            ].defaultBranchVersion?.id,
            nil
        )
    }

    func test_releaseVersion() throws {
        XCTAssertEqual(
            [
                Version(id: .id0, latest: .defaultBranch),
                Version(id: .id1, latest: .release)
            ].releaseVersion?.id,
            .id1
        )
        XCTAssertEqual(
            [
                Version(id: .id0, latest: .defaultBranch),
                Version(id: .id1, latest: .preRelease),
            ].releaseVersion?.id,
            nil
        )
    }

    func test_documentationTarget_external() throws {
        // Test with only external link
        XCTAssertEqual(
            [
                Version(id: .id0, latest: .release),
                Version(id: .id1, latest: .defaultBranch, spiManifest: .withExternalDocLink("link")),
            ].canonicalDocumentationTarget(),
            .external(url: "link")
        )

        // Test external link overrides generated docs
        XCTAssertEqual(
            [
                Version(id: .id0, latest: .release),
                Version(id: .id1, latest: .defaultBranch,
                        spiManifest: .withExternalDocLink("link"),
                        docArchives: [.init(name: "foo", title: "Foo")]),
            ].canonicalDocumentationTarget(),
            .external(url: "link")
        )

        // Test external link overrides generated docs, also if they're release docs
        XCTAssertEqual(
            [
                Version(id: .id0, latest: .release,
                        docArchives: [.init(name: "foo", title: "Foo")]),
                Version(id: .id1, latest: .defaultBranch,
                        spiManifest: .withExternalDocLink("link")),
            ].canonicalDocumentationTarget(),
            .external(url: "link")
        )
    }

    func test_documentationTarget_internal() throws {
        // Test default path - release docs available
        XCTAssertEqual(
            [
                Version(id: .id0, latest: .release, reference: .tag(1, 2, 3),
                        docArchives: [.init(name: "foo", title: "Foo")]),
            ].canonicalDocumentationTarget(),
            .internal(reference: "1.2.3", archive: "foo")
        )

        // Test default branch fallback
        XCTAssertEqual(
            [
                Version(id: .id0, latest: .release, reference: .tag(1, 2, 3)),
                Version(id: .id0, latest: .defaultBranch, reference: .branch("main"),
                        docArchives: [.init(name: "foo", title: "Foo")]),
            ].canonicalDocumentationTarget(),
            .internal(reference: "main", archive: "foo")
        )

        // No default branch version available
        XCTAssertEqual(
            [
                Version(id: .id0, latest: .release, reference: .tag(1, 2, 3)),
            ].canonicalDocumentationTarget(),
            nil
        )

        // No doc archives available at all
        XCTAssertEqual(
            [
                Version(id: .id0, latest: .release, reference: .tag(1, 2, 3)),
                Version(id: .id0, latest: .defaultBranch, reference: .branch("main")),
            ].canonicalDocumentationTarget(),
            nil
        )

        // Or simply no versions in array at all
        XCTAssertEqual([Version]().canonicalDocumentationTarget(), nil)
    }

}


private extension Version {
    convenience init(id: Version.Id,
                     latest: Version.Kind,
                     reference: Reference? = nil,
                     spiManifest: SPIManifest.Manifest? = nil,
                     docArchives: [DocArchive]? = nil) {
        self.init()
        self.id = id
        if let reference {
            self.reference = reference
        }
        self.spiManifest = spiManifest
        self.docArchives = docArchives
        self.latest = latest
    }
}


private extension SPIManifest.Manifest {
    static func withExternalDocLink(_ link: String) -> Self {
        .init(externalLinks: .init(documentation: link))
    }
}
