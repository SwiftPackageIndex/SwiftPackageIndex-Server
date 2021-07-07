@testable import App

import Vapor
import XCTest

class KeywordControllerTests: AppTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()

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
    }

    func test_query() throws {
        // MUT
        let packages = try KeywordController.query(on: app.db,
                                                   keyword: "foo",
                                                   page: 1,
                                                   pageSize: 10).wait()

        // validation
        XCTAssertEqual(packages.map(\.id), [.id1])
    }

    // TODO: test pagination

    func test_show_keyword() throws {
        try app.test(.GET, "/keywords/foo") {
            XCTAssertEqual($0.status, .ok)
        }
    }

    func test_not_found() throws {
        try app.test(.GET, "/keywords/baz") {
            XCTAssertEqual($0.status, .notFound)
        }
    }

}
