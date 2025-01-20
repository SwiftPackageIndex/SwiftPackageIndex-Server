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

import Dependencies
import Fluent
import Vapor


class CustomCollectionControllerTests: AppTestCase {

    func test_query() async throws {
        // setup
        try await CustomCollection.save(
            on: app.db,
            key: "list",
            name: "List",
            url: "https://github.com/foo/bar/list.json",
            packages: [( id: .id0, url: "https://github.com/foo/1", owner: "foo", name: "1" )]
        )

        // MUT
        let page = try await CustomCollectionsController.query(on: app.db,
                                                               key: "list",
                                                               page: 1,
                                                               pageSize: 10)

        // validation
        XCTAssertEqual(page.results.map(\.repository.name), ["1"])
        XCTAssertEqual(page.hasMoreResults, false)
    }

    func test_query_pagination() async throws {
        // setup
        let pkgInfo = [UUID.id0, .id1, .id2, .id3, .id4].enumerated().shuffled().map { (idx, id) in
            (id, URL(string: "https://github.com/foo/\(idx)")!, "foo", "\(idx)")
        }
        try await CustomCollection.save(
            on: app.db,
            key: "list",
            name: "List",
            url: "https://github.com/foo/bar/list.json",
            packages: pkgInfo
        )

        do {  // first page
              // MUT
            let page = try await CustomCollectionsController.query(on: app.db,
                                                                   key: "list",
                                                                   page: 1,
                                                                   pageSize: 2)
            // validate
            XCTAssertEqual(page.results.map(\.repository.name), ["0", "1"])
            XCTAssertEqual(page.hasMoreResults, true)
        }

        do {  // second page
              // MUT
            let page = try await CustomCollectionsController.query(on: app.db,
                                                                   key: "list",
                                                                   page: 2,
                                                                   pageSize: 2)
            // validate
            XCTAssertEqual(page.results.map(\.repository.name), ["2", "3"])
            XCTAssertEqual(page.hasMoreResults, true)
        }

        do {  // first page
              // MUT
            let page = try await CustomCollectionsController.query(on: app.db,
                                                                   key: "list",
                                                                   page: 3,
                                                                   pageSize: 2)
            // validate
            XCTAssertEqual(page.results.map(\.repository.name), ["4"])
            XCTAssertEqual(page.hasMoreResults, false)
        }
    }

}


private extension CustomCollection {
    @discardableResult
    static func save(on database: Database, key: String, name: String, url: URL, packages: [(id: Package.Id, url: URL, owner: String, name: String)]) async throws -> CustomCollection {
        let packages = try await packages.mapAsync {
            let pkg = Package(id: $0.id, url: $0.url)
            try await pkg.save(on: database)
            try await Repository(package: pkg, name: $0.name, owner: $0.owner).save(on: database)
            try await Version(package: pkg, latest: .defaultBranch).save(on: database)
            return pkg
        }
        let collection = CustomCollection(id: .id1, .init(key: key, name: name, url: url))
        try await collection.save(on: database)
        try await collection.$packages.attach(packages, on: database)
        return collection
    }
}
