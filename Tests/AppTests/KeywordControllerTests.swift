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

import Vapor
import XCTest

class KeywordControllerTests: AppTestCase {

    func test_query() throws {
        // setup
        do {
            let p = Package(id: .id0, url: "0".asGithubUrl.url)
            let r = try Repository(id: UUID(),
                                   package: p,
                                   keywords: ["bar"],
                                   name: "0",
                                   owner: "owner")
            try p.save(on: app.db).wait()
            try r.save(on: app.db).wait()
        }
        do {
            let p = Package(id: .id1, url: "1".asGithubUrl.url)
            let r = try Repository(id: UUID(),
                                   package: p,
                                   keywords: ["foo"],
                                   name: "1",
                                   owner: "owner")
            try p.save(on: app.db).wait()
            try r.save(on: app.db).wait()
        }
        do {
            let p = Package(id: .id2, url: "2".asGithubUrl.url)
            let r = try Repository(id: UUID(),
                                   package: p,
                                   name: "2",
                                   owner: "owner")
            try p.save(on: app.db).wait()
            try r.save(on: app.db).wait()
        }
        // MUT
        let res = try KeywordController.query(on: app.db,
                                                   keyword: "foo",
                                                   page: 1,
                                                   pageSize: 10).wait()

        // validation
        XCTAssertEqual(res.packages.map(\.model.id), [.id1])
        XCTAssertEqual(res.hasMoreResults, false)
    }

    func test_query_pagination() throws {
        // setup
        for (idx, id) in UUID.mockAll.prefix(9).enumerated() {
            let p = Package(id: id, url: "\(idx)".asGithubUrl.url, score: 10 - idx)
            let r = try Repository(id: UUID(),
                                   package: p,
                                   keywords: ["foo"],
                                   name: "\(idx)",
                                   owner: "owner")
            try p.save(on: app.db).wait()
            try r.save(on: app.db).wait()
        }
        do {  // first page
            // MUT
            let res = try KeywordController.query(on: app.db,
                                                  keyword: "foo",
                                                  page: 1,
                                                  pageSize: 3).wait()
            // validate
            XCTAssertEqual(res.packages.map(\.model.id), [.id0, .id1, .id2])
            XCTAssertEqual(res.hasMoreResults, true)
        }
        do {  // second page
            // MUT
            let res = try KeywordController.query(on: app.db,
                                                  keyword: "foo",
                                                  page: 2,
                                                  pageSize: 3).wait()
            // validate
            XCTAssertEqual(res.packages.map(\.model.id), [.id3, .id4, .id5])
            XCTAssertEqual(res.hasMoreResults, true)
        }
        do {  // last page
            // MUT
            let res = try KeywordController.query(on: app.db,
                                                  keyword: "foo",
                                                  page: 3,
                                                  pageSize: 3).wait()
            // validate
            XCTAssertEqual(res.packages.map(\.model.id), [.id6, .id7, .id8])
            XCTAssertEqual(res.hasMoreResults, false)
        }
    }

    func test_show_keyword() throws {
        // setup
        do {
            let p = Package(id: .id1, url: "1".asGithubUrl.url)
            let r = try Repository(id: UUID(),
                                   package: p,
                                   keywords: ["foo"],
                                   name: "1",
                                   owner: "owner")
            try p.save(on: app.db).wait()
            try r.save(on: app.db).wait()
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
