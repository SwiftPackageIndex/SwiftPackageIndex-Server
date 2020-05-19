@testable import App

import Vapor
import XCTest


class ApiTests: AppTestCase {

    func test_version() throws {
        try app.test(.GET, "api/version") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(API.Version.self),
                           API.Version(version: "dev - will be overriden in release builds"))
        }
    }

    func test_search_basic() throws {
        try app.test(.GET, "api/search") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(
                try res.content.decode([API.SearchResult].self),
                [
                    .init(packageName: "FooBar", repositoryID: "someone/FooBar", summary: "A foo bar repo"),
                    .init(packageName: "BazBaq", repositoryID: "another/barbaq", summary: "Some other repo"),
            ])
        }
    }
}
