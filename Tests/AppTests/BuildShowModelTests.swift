@testable import App

import XCTVapor


class BuildShowModelTests: AppTestCase {

    func test_buildsURL() throws {
        XCTAssertEqual(Model.mock.buildsURL, "/foo/bar/builds")
    }

    func test_query_packageName() throws {
        // Ensure relations are fully loaded to allow resolving of package name
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       summary: "summary",
                       defaultBranch: "main",
                       license: .mit,
                       name: "bar",
                       owner: "foo",
                       stars: 17,
                       forks: 42).save(on: app.db).wait()
        let v = try Version(id: UUID(), package: pkg, reference: .branch("main"), packageName: "Bar")
        try v.save(on: app.db).wait()
        let buildId = UUID()
        let build = try Build(id: buildId, version: v, platform: .ios, status: .ok, swiftVersion: .init(5, 3, 0))
        try build.save(on: app.db).wait()

        // MUT
        let m = try Build.query(on: app.db, buildId: buildId)
            .map(BuildShow.Model.init(build:))
            .wait()

        // validate
        XCTAssertEqual(m?.packageName, "Bar")
    }

}


fileprivate typealias Model = BuildShow.Model
