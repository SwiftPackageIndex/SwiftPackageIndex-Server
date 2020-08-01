@testable import App

import XCTVapor


class BuildShowModelTests: AppTestCase {

    func test_buildsURL() throws {
        XCTAssertEqual(Model.mock.buildsURL, "/foo/bar/builds")
    }

    func test_packageURL() throws {
        XCTAssertEqual(Model.mock.packageURL, "/foo/bar")
    }

    func test_Build_query() throws {
        // Tests Build.query as it is used in BuildController by validating
        // packageName. This property requires relations to be fully loaded,
        // which is what Build.query is taking care of.
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
        let v = try Version(id: UUID(), package: pkg, packageName: "Bar", reference: .branch("main"))
        try v.save(on: app.db).wait()
        let buildId = UUID()
        let build = try Build(id: buildId, version: v, platform: .ios, status: .ok, swiftVersion: .init(5, 3, 0))
        try build.save(on: app.db).wait()
        // re-load repository relationship (required for updateLatestVersions)
        try pkg.$repositories.load(on: app.db).wait()
        // update versions
        _ = try updateLatestVersions(on: app.db, package: pkg).wait()

        // MUT
        let m = try Build.query(on: app.db, buildId: buildId)
            .map(BuildShow.Model.init(build:))
            .wait()

        // validate
        XCTAssertEqual(m?.packageName, "Bar")
    }

}


fileprivate typealias Model = BuildShow.Model
