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

@testable import App

import Vapor
import XCTest

class KeywordControllerTests: AppTestCase {

    func test_query() throws {
        // setup
        do {
            let p = try savePackage(on: app.db, "0")
            try Repository(package: p,
                           keywords: ["bar"],
                           name: "0",
                           owner: "owner")
                .save(on: app.db).wait()
            try Version(package: p, latest: .defaultBranch).save(on: app.db).wait()
        }
        do {
            let p = try savePackage(on: app.db, "1")
            try Repository(package: p,
                           keywords: ["foo"],
                           name: "1",
                           owner: "owner")
                .save(on: app.db).wait()
            try Version(package: p, latest: .defaultBranch).save(on: app.db).wait()
        }
        do {
            let p = try savePackage(on: app.db, "2")
            try Repository(package: p,
                           name: "2",
                           owner: "owner")
                .save(on: app.db).wait()
            try Version(package: p, latest: .defaultBranch).save(on: app.db).wait()
        }
        // MUT
        let page = try KeywordController.query(on: app.db,
                                               keyword: "foo",
                                               page: 1,
                                               pageSize: 10).wait()

        // validation
        XCTAssertEqual(page.results.map(\.model.url), ["1"])
        XCTAssertEqual(page.hasMoreResults, false)
    }

    func test_query_pagination() throws {
        // setup
        try (0..<9).shuffled().forEach { idx in
            let p = Package(url: "\(idx)".url, score: 10 - idx)
            try p.save(on: app.db).wait()
            try Repository(package: p,
                           keywords: ["foo"],
                           name: "\(idx)",
                           owner: "owner").save(on: app.db).wait()
            try Version(package: p, latest: .defaultBranch).save(on: app.db).wait()
        }
        do {  // first page
            // MUT
            let page = try KeywordController.query(on: app.db,
                                                   keyword: "foo",
                                                   page: 1,
                                                   pageSize: 3).wait()
            // validate
            XCTAssertEqual(page.results.map(\.model.url), ["0", "1", "2"])
            XCTAssertEqual(page.hasMoreResults, true)
        }
        do {  // second page
            // MUT
            let page = try KeywordController.query(on: app.db,
                                                   keyword: "foo",
                                                   page: 2,
                                                   pageSize: 3).wait()
            // validate
            XCTAssertEqual(page.results.map(\.model.url), ["3", "4", "5"])
            XCTAssertEqual(page.hasMoreResults, true)
        }
        do {  // last page
            // MUT
            let page = try KeywordController.query(on: app.db,
                                                   keyword: "foo",
                                                   page: 3,
                                                   pageSize: 3).wait()
            // validate
            XCTAssertEqual(page.results.map(\.model.url), ["6", "7", "8"])
            XCTAssertEqual(page.hasMoreResults, false)
        }
    }

    func test_show_keyword() throws {
        // setup
        do {
            let p = try savePackage(on: app.db, "1")
            try Repository(package: p,
                           keywords: ["foo"],
                           name: "1",
                           owner: "owner").save(on: app.db).wait()
            try Version(package: p, latest: .defaultBranch).save(on: app.db).wait()
        }
        // MUT
        try app.test(.GET, "/keywords/foo") {
            // validate
            XCTAssertEqual($0.status, .ok)
        }
    }

    func test_not_found() throws {
        try app.test(.GET, "/keywords/baz") {
            XCTAssertEqual($0.status, .notFound)
        }
    }

}
