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


class CustomCollectionTests: ParallelizedAppTestCase {

    func test_CustomCollection_save() async throws {
        // MUT
        try await CustomCollection(id: .id0, .init(key: "list",
                                                   name: "List",
                                                   url: "https://github.com/foo/bar/list.json"))
            .save(on: app.db)

        do { // validate
            let collection = try await CustomCollection.find(.id0, on: app.db).unwrap()
            XCTAssertEqual(collection.key, "list")
            XCTAssertEqual(collection.name, "List")
            XCTAssertEqual(collection.url, "https://github.com/foo/bar/list.json")
        }

        do { // ensure key is unique
            try await CustomCollection(.init(key: "list",
                                             name: "List 2",
                                             url: "https://github.com/foo/bar/other-list.json"))
                .save(on: app.db)
            XCTFail("Expected failure")
        } catch {
            let msg = String(reflecting: error)
            XCTAssert(msg.contains(#"duplicate key value violates unique constraint "uq:custom_collections.key""#),
                      "was: \(msg)")
        }
        do { // ensure name is unique
            try await CustomCollection(.init(key: "list-2",
                                             name: "List",
                                             url: "https://github.com/foo/bar/other-list.json"))
                .save(on: app.db)
            XCTFail("Expected failure")
        } catch {
            let msg = String(reflecting: error)
            XCTAssert(msg.contains(#"duplicate key value violates unique constraint "uq:custom_collections.name""#),
                      "was: \(msg)")
        }

        do { // ensure url is unique
            try await CustomCollection(.init(key: "list-2",
                                             name: "List 2",
                                             url: "https://github.com/foo/bar/list.json"))
                .save(on: app.db)
            XCTFail("Expected failure")
        } catch {
            let msg = String(reflecting: error)
            XCTAssert(msg.contains(#"duplicate key value violates unique constraint "uq:custom_collections.url""#),
                      "was: \(msg)")
        }
    }

    func test_CustomCollection_findOrCreate() async throws {
        do { // initial call creates collection
            // MUT
            let res = try await CustomCollection.findOrCreate(on: app.db, .init(key: "list",
                                                                                name: "List",
                                                                                url: "url"))

            // validate
            XCTAssertEqual(res.key, "list")
            XCTAssertEqual(res.name, "List")
            XCTAssertEqual(res.url, "url")

            let c = try await CustomCollection.query(on: app.db).all()
            XCTAssertEqual(c.count, 1)
            XCTAssertEqual(c.first?.key, "list")
            XCTAssertEqual(c.first?.name, "List")
            XCTAssertEqual(c.first?.url, "url")
        }

        do { // re-running is idempotent
            // MUT
            let res = try await CustomCollection.findOrCreate(on: app.db, .init(key: "list",
                                                                                name: "List",
                                                                                url: "url"))

            // validate
            XCTAssertEqual(res.key, "list")
            XCTAssertEqual(res.name, "List")
            XCTAssertEqual(res.url, "url")

            let c = try await CustomCollection.query(on: app.db).all()
            XCTAssertEqual(c.count, 1)
            XCTAssertEqual(c.first?.key, "list")
            XCTAssertEqual(c.first?.name, "List")
            XCTAssertEqual(c.first?.url, "url")
        }

        do { // a record is updated if data has changed
             // MUT
             let res = try await CustomCollection.findOrCreate(on: app.db, .init(key: "list",
                                                                                 name: "New name",
                                                                                 url: "new-url"))
            // validate
            XCTAssertEqual(res.key, "list")
            XCTAssertEqual(res.name, "New name")
            XCTAssertEqual(res.url, "new-url")

            let c = try await CustomCollection.query(on: app.db).all()
            XCTAssertEqual(c.count, 1)
            XCTAssertEqual(c.first?.key, "list")
            XCTAssertEqual(c.first?.name, "New name")
            XCTAssertEqual(c.first?.url, "new-url")
        }
    }

    func test_CustomCollectionPackage_attach() async throws {
        // setup
        let pkg = Package(id: .id0, url: "1".asGithubUrl.url)
        try await pkg.save(on: app.db)
        let collection = CustomCollection(id: .id1, .init(key: "list",
                                                          name: "List",
                                                          url: "https://github.com/foo/bar/list.json"))
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
            XCTAssertEqual(pivot.customCollection.key, "list")
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
        let collection = CustomCollection(id: .id1, .init(key: "list",
                                                          name: "List",
                                                          url: "https://github.com/foo/bar/list.json"))
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
        // Test CustomCollection.packages relation
        // setup
        let p1 = Package(id: .id0, url: "1".asGithubUrl.url)
        try await p1.save(on: app.db)
        let p2 = Package(id: .id1, url: "2".asGithubUrl.url)
        try await p2.save(on: app.db)
        let collection = CustomCollection(id: .id2, .init(key: "list",
                                                          name: "List",
                                                          url: "https://github.com/foo/bar/list.json"))
        try await collection.save(on: app.db)
        try await collection.$packages.attach([p1, p2], on: app.db)

        do { // MUT
            let collection = try await CustomCollection.find(.id2, on: app.db).unwrap()
            try await collection.$packages.load(on: app.db)
            let packages = collection.packages
            XCTAssertEqual(Set(packages.map(\.id)) , Set([.id0, .id1]))
        }
    }

    func test_Package_customCollections() async throws {
        // Test Package.customCollections relation
        // setup
        let p1 = Package(id: .id0, url: "1".asGithubUrl.url)
        try await p1.save(on: app.db)
        do {
            let collection = CustomCollection(id: .id1, .init(key: "list-1",
                                                              name: "List 1",
                                                              url: "https://github.com/foo/bar/list-1.json"))
            try await collection.save(on: app.db)
            try await collection.$packages.attach(p1, on: app.db)
        }
        do {
            let collection = CustomCollection(id: .id2, .init(key: "list-2",
                                                              name: "List 2",
                                                              url: "https://github.com/foo/bar/list-2.json"))
            try await collection.save(on: app.db)
            try await collection.$packages.attach(p1, on: app.db)
        }

        do { // MUT
            let pkg = try await Package.find(.id0, on: app.db).unwrap()
            try await pkg.$customCollections.load(on: app.db)
            XCTAssertEqual(Set(pkg.customCollections.map(\.id)) , Set([.id1, .id2]))
        }
    }

    func test_CustomCollection_cascade() async throws {
        // setup
        let pkg = Package(id: .id0, url: "1".asGithubUrl.url)
        try await pkg.save(on: app.db)
        let collection = CustomCollection(id: .id1, .init(key: "list",
                                                          name: "List",
                                                          url: "https://github.com/foo/bar/list.json"))
        try await collection.save(on: app.db)
        try await collection.$packages.attach(pkg, on: app.db)
        do {
            let count = try await CustomCollection.query(on: app.db).count()
            XCTAssertEqual(count, 1)
        }
        do {
            let count = try await CustomCollectionPackage.query(on: app.db).count()
            XCTAssertEqual(count, 1)
        }
        do {
            let count = try await Package.query(on: app.db).count()
            XCTAssertEqual(count, 1)
        }

        // MUT
        try await collection.delete(on: app.db)

        // validation
        do {
            let count = try await CustomCollection.query(on: app.db).count()
            XCTAssertEqual(count, 0)
        }
        do {
            let count = try await CustomCollectionPackage.query(on: app.db).count()
            XCTAssertEqual(count, 0)
        }
        do {
            let count = try await Package.query(on: app.db).count()
            XCTAssertEqual(count, 1)
        }
    }

    func test_Package_cascade() async throws {
        // setup
        let pkg = Package(id: .id0, url: "1".asGithubUrl.url)
        try await pkg.save(on: app.db)
        let collection = CustomCollection(id: .id1, .init(key: "list",
                                                          name: "List",
                                                          url: "https://github.com/foo/bar/list.json"))
        try await collection.save(on: app.db)
        try await collection.$packages.attach(pkg, on: app.db)
        do {
            let count = try await CustomCollection.query(on: app.db).count()
            XCTAssertEqual(count, 1)
        }
        do {
            let count = try await CustomCollectionPackage.query(on: app.db).count()
            XCTAssertEqual(count, 1)
        }
        do {
            let count = try await Package.query(on: app.db).count()
            XCTAssertEqual(count, 1)
        }

        // MUT
        try await pkg.delete(on: app.db)

        // validation
        do {
            let count = try await CustomCollection.query(on: app.db).count()
            XCTAssertEqual(count, 1)
        }
        do {
            let count = try await CustomCollectionPackage.query(on: app.db).count()
            XCTAssertEqual(count, 0)
        }
        do {
            let count = try await Package.query(on: app.db).count()
            XCTAssertEqual(count, 0)
        }
    }

    func test_CustomCollection_reconcile() async throws {
        // Test reconciliation of a custom collection against a list of package URLs
        let collection = CustomCollection(id: .id0, .init(key: "list",
                                                          name: "List",
                                                          url: "https://github.com/foo/bar/list.json"))
        try await collection.save(on: app.db)
        try await Package(id: .id1, url: URL("https://github.com/a.git")).save(on: app.db)
        try await Package(id: .id2, url: URL("https://github.com/b.git")).save(on: app.db)

        do { // Initial set of URLs
            // MUT
            try await collection.reconcile(on: app.db, packageURLs: [URL("https://github.com/a.git")])

            do { // validate
                let count = try await CustomCollectionPackage.query(on: app.db).count()
                XCTAssertEqual(count, 1)
                let collection = try await CustomCollection.find(.id0, on: app.db).unwrap()
                try await collection.$packages.load(on: app.db)
                XCTAssertEqual(collection.packages.map(\.url), ["https://github.com/a.git"])
            }
        }

        do { // Add more URLs
            // MUT
            try await collection.reconcile(on: app.db, packageURLs: [
                URL("https://github.com/a.git"),
                URL("https://github.com/b.git")
            ])

            do { // validate
                let count = try await CustomCollectionPackage.query(on: app.db).count()
                XCTAssertEqual(count, 2)
                let collection = try await CustomCollection.find(.id0, on: app.db).unwrap()
                try await collection.$packages.load(on: app.db)
                XCTAssertEqual(collection.packages.map(\.url).sorted(), [
                    "https://github.com/a.git",
                    "https://github.com/b.git"
                ])
            }
        }

        do { // Remove URLs
            // MUT
            try await collection.reconcile(on: app.db, packageURLs: [
                URL("https://github.com/b.git")
            ])

            do { // validate
                let count = try await CustomCollectionPackage.query(on: app.db).count()
                XCTAssertEqual(count, 1)
                let collection = try await CustomCollection.find(.id0, on: app.db).unwrap()
                try await collection.$packages.load(on: app.db)
                XCTAssertEqual(collection.packages.map(\.url), ["https://github.com/b.git"])
            }
        }
    }

    func test_CustomCollection_reconcile_caseInsensitive() async throws {
        // Test reconciliation with a case-insensitive matching URL
        let collection = CustomCollection(id: .id0, .init(key: "list",
                                                          name: "List",
                                                          url: "https://github.com/foo/bar/list.json"))
        try await collection.save(on: app.db)
        try await Package(id: .id1, url: URL("https://github.com/a.git")).save(on: app.db)

        // MUT
        try await collection.reconcile(on: app.db, packageURLs: [URL("https://github.com/A.git")])

        do { // validate
            // The package is added to the custom collection via case-insensitive match
            let count = try await CustomCollectionPackage.query(on: app.db).count()
            XCTAssertEqual(count, 1)
            let collection = try await CustomCollection.find(.id0, on: app.db).unwrap()
            try await collection.$packages.load(on: app.db)
            XCTAssertEqual(collection.packages.map(\.url), ["https://github.com/a.git"])
        }
    }

}
