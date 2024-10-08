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


class CustomCollectionTests: AppTestCase {

    func test_CustomCollection_save() async throws {
        // MUT
        try await CustomCollection(id: .id0, name: "List", url: "https://github.com/foo/bar/list.json")
            .save(on: app.db)

        do { // validate
            let collection = try await CustomCollection.find(.id0, on: app.db).unwrap()
            XCTAssertEqual(collection.name, "List")
            XCTAssertEqual(collection.url, "https://github.com/foo/bar/list.json")
        }

        do { // ensure name is unique
            try await CustomCollection(name: "List", url: "https://github.com/foo/bar/other-list.json")
                .save(on: app.db)
            XCTFail("Expected failure")
        } catch {
            let msg = String(reflecting: error)
            XCTAssert(msg.contains(#"duplicate key value violates unique constraint "uq:custom_collections.name""#),
                      "was: \(msg)")
        }

        do { // ensure url is unique
            try await CustomCollection(name: "List 2", url: "https://github.com/foo/bar/list.json")
                .save(on: app.db)
            XCTFail("Expected failure")
        } catch {
            let msg = String(reflecting: error)
            XCTAssert(msg.contains(#"duplicate key value violates unique constraint "uq:custom_collections.url""#),
                      "was: \(msg)")
        }
    }

    func test_CustomCollectionPackage_attach() async throws {
        // setup
        let pkg = Package(id: .id0, url: "1".asGithubUrl.url)
        try await pkg.save(on: app.db)
        let collection = CustomCollection(id: .id1, name: "List", url: "https://github.com/foo/bar/list.json")
        try await collection.save(on: app.db)

        // MUT
        try await collection.$packages.attach(pkg, on: app.db)

        do { // validate
            let count = try await CustomCollectionPackage.query(on: app.db).count()
            XCTAssertEqual(count, 1)
            let pivot = try await CustomCollectionPackage.query(on: app.db).first().unwrap()
            try await pivot.$package.load(on: app.db)
            XCTAssertEqual(pivot.package.id, .id0)
            XCTAssertEqual(pivot.package.url, "1".asGithubUrl)
            try await pivot.$customCollection.load(on: app.db)
            XCTAssertEqual(pivot.customCollection.id, .id1)
            XCTAssertEqual(pivot.customCollection.name, "List")
        }

        do { // ensure package is unique per list
            try await collection.$packages.attach(pkg, on: app.db)
        } catch {
            let msg = String(reflecting: error)
            XCTAssert(msg.contains(#"duplicate key value violates unique constraint "uq:custom_collections+packages.custom_collection_id+custom_coll""#),
                      "was: \(msg)")
        }
    }

    func test_CustomCollectionPackage_detach() async throws {
        // setup
        let pkg = Package(id: .id0, url: "1".asGithubUrl.url)
        try await pkg.save(on: app.db)
        let collection = CustomCollection(id: .id1, name: "List", url: "https://github.com/foo/bar/list.json")
        try await collection.save(on: app.db)
        try await collection.$packages.attach(pkg, on: app.db)

        // MUT
        try await collection.$packages.detach(pkg, on: app.db)

        do { // validate
            let count = try await CustomCollectionPackage.query(on: app.db).count()
            XCTAssertEqual(count, 0)
        }

        do { // ensure packag and collection are untouched
            _ = try await Package.find(.id0, on: app.db).unwrap()
            _ = try await CustomCollection.find(.id1, on: app.db).unwrap()
        }
    }

    func test_CustomCollection_packages() async throws {
        // setup
        let p1 = Package(id: .id0, url: "1".asGithubUrl.url)
        try await p1.save(on: app.db)
        let p2 = Package(id: .id1, url: "2".asGithubUrl.url)
        try await p2.save(on: app.db)
        let collection = CustomCollection(id: .id2, name: "List", url: "https://github.com/foo/bar/list.json")
        try await collection.save(on: app.db)
        try await collection.$packages.attach([p1, p2], on: app.db)

        do { // MUT
            let collection = try await CustomCollection.find(.id2, on: app.db).unwrap()
            try await collection.$packages.load(on: app.db)
            let packages = collection.packages
            XCTAssertEqual(Set(packages.map(\.id)) , Set([.id0, .id1]))
        }
    }

}
