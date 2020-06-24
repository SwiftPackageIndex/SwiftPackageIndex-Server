@testable import App

import XCTVapor


class ApiTests: AppTestCase {

    func test_version() throws {
        try app.test(.GET, "api/version") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(API.Version.self),
                           API.Version(version: "dev - will be overriden in release builds"))
        }
    }

    func test_search_noQuery() throws {
        try app.test(.GET, "api/search") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(Search.Result.self),
                           .init(hasMoreResults: false, results: []))
        }
    }

    func test_search_basic_param() throws {
        // setup
        let p1 = Package(id: UUID(uuidString: "442cf59f-0135-4d08-be00-bc9a7cebabd3")!,
                         url: "1")
        try p1.save(on: app.db).wait()
        let p2 = Package(id: UUID(uuidString: "4e256250-d1ea-4cdd-9fe9-0fc5dce17a80")!,
                         url: "2")
        try p2.save(on: app.db).wait()
        try Repository(package: p1,
                       summary: "some package",
                       defaultBranch: "main").save(on: app.db).wait()
        try Repository(package: p2,
                       summary: "foo bar package",
                       defaultBranch: "main",
                       name: "name 2",
                       owner: "owner 2").save(on: app.db).wait()
        try Version(package: p1, reference: .branch("main"), packageName: "Foo").save(on: app.db).wait()
        try Version(package: p2, reference: .branch("main"), packageName: "Bar").save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        // MUT
        try app.test(.GET, "api/search?query=foo%20bar") { res in
            // validation
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(
                try res.content.decode(Search.Result.self),
                .init(hasMoreResults: false,
                      results: [
                        .init(packageId: UUID(uuidString: "4e256250-d1ea-4cdd-9fe9-0fc5dce17a80")!,
                              packageName: "Bar",
                              packageURL: "/owner%202/name%202",
                              repositoryName: "name 2",
                              repositoryOwner: "owner 2",
                              summary: "foo bar package"),
                ])
            )
        }
    }

    func test_post_build() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p)
        try v.save(on: app.db).wait()
        let versionId = try XCTUnwrap(v.id)
        let dto: Build.PostDTO = .init(status: .ok, swiftVersion: .init(5, 2, 0))
        let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))

        // MUT
        try app.test(
            .POST,
            "api/versions/\(versionId)/builds",
            headers: .init(dictionaryLiteral: ("Content-Type", "application/json")),
            body: body) { res in
                // validation
                XCTAssertEqual(res.status, .ok)
                struct DTO: Decodable {
                    var id: Build.Id?
                }
                let dto = try JSONDecoder().decode(DTO.self, from: res.body)
                let b = try XCTUnwrap(Build.find(dto.id, on: app.db).wait())
                XCTAssertEqual(b.status, .ok)
                XCTAssertEqual(b.swiftVersion, .init(5, 2, 0))
        }
    }

}
