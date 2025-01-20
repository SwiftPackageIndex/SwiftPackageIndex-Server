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
import Vapor


class CustomCollectionControllerTests: AppTestCase {

    func test_query() async throws {
        // setup
        let pkg = Package(id: .id0, url: "1".asGithubUrl.url)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg, name: "1", owner: "owner").save(on: app.db)
        try await Version(package: pkg, latest: .defaultBranch).save(on: app.db)
        let collection = CustomCollection(id: .id1, .init(key: "list",
                                                          name: "List",
                                                          url: "https://github.com/foo/bar/list.json"))
        try await collection.save(on: app.db)
        try await collection.$packages.attach([pkg], on: app.db)

        // MUT
        let page = try await CustomCollectionsController.query(on: app.db,
                                                               key: "list",
                                                               page: 1,
                                                               pageSize: 10)

        // validation
        XCTAssertEqual(page.results.map(\.repository.name), ["1"])
        XCTAssertEqual(page.hasMoreResults, false)
    }

}
