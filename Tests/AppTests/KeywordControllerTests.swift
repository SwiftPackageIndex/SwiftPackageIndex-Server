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
        XCTAssertEqual(res.packages.map(\.id), [.id1])
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
            XCTAssertEqual(res.packages.map(\.id), [.id0, .id1, .id2])
            XCTAssertEqual(res.hasMoreResults, true)
        }
        do {  // second page
            // MUT
            let res = try KeywordController.query(on: app.db,
                                                  keyword: "foo",
                                                  page: 2,
                                                  pageSize: 3).wait()
            // validate
            XCTAssertEqual(res.packages.map(\.id), [.id3, .id4, .id5])
            XCTAssertEqual(res.hasMoreResults, true)
        }
        do {  // last page
            // MUT
            let res = try KeywordController.query(on: app.db,
                                                  keyword: "foo",
                                                  page: 3,
                                                  pageSize: 3).wait()
            // validate
            XCTAssertEqual(res.packages.map(\.id), [.id6, .id7, .id8])
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
