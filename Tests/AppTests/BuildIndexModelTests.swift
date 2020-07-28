@testable import App

import XCTVapor


class BuildIndexModelTests: AppTestCase {

    func test_init_no_name() throws {
        // Tests behaviour when we're lacking data
        // setup package without package name
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       summary: "summary",
                       defaultBranch: "main",
                       license: .mit,
                       name: "bar",
                       owner: "foo",
                       stars: 17,
                       forks: 42).save(on: app.db).wait()

        // MUT
        let m = BuildIndex.Model(package: pkg)

        // validate
        XCTAssertNil(m)
    }

    func test_buildCount() throws {
        let m = BuildIndex.Model.mock
        XCTAssertEqual(m.buildCount, 72)
    }

    func test_packageURL() throws {
        let m = BuildIndex.Model.mock
        XCTAssertEqual(m.packageURL, "/foo/foobar")
    }

    func test_buildMatrix() throws {
        // setup
        let id = UUID()
        let stable: [BuildInfo] = [
            .init(id: id, swiftVersion: .init(5, 3, 0), platform: .ios, status: .ok),
            .init(id: id, swiftVersion: .init(5, 2, 0), platform: .macosXcodebuild, status: .ok),
            .init(id: id, swiftVersion: .init(5, 1, 0), platform: .tvos, status: .ok),
        ]
        let latest: [BuildInfo] = [
            .init(id: id, swiftVersion: .init(5, 2, 0), platform: .macosSpm, status: .failed),
            .init(id: id, swiftVersion: .init(5, 1, 0), platform: .tvos, status: .ok),
        ]
        let model = BuildIndex.Model.init(owner: "foo",
                                          repositoryName: "bar",
                                          packageName: "bar",
                                          buildGroups: [
                                            .init(name: "1.2.3", kind: .stable, builds: stable),
                                            .init(name: "2.0.0-beta", kind: .beta, builds: []),
                                            .init(name: "main", kind: .latest, builds: latest),
                                          ])

        // MUT
        let matrix = model.buildMatrix

        // validate
        XCTAssertEqual(BuildIndex.Model.BuildMatrix.RowIndex.all.count, 40)
        XCTAssertEqual(matrix.columnLabels, ["1.2.3", "2.0.0-beta", "main"])
        XCTAssertEqual(matrix.values.keys.count, 40)
        XCTAssertEqual(matrix.values.keys.sorted(by: RowIndex.versionPlatform).map(\.label).first, "Swift 5.3 on iOS")
        XCTAssertEqual(
            matrix.values[.init(swiftVersion: .v5_3, platform: .ios)], [.ok, nil, nil]
        )
        XCTAssertEqual(
            matrix.values[.init(swiftVersion: .v5_2, platform: .macosXcodebuild)], [.ok, nil, nil]
        )
        XCTAssertEqual(
            matrix.values[.init(swiftVersion: .v5_2, platform: .macosSpm)], [nil, nil, .failed]
        )
        XCTAssertEqual(
            matrix.values[.init(swiftVersion: .v5_1, platform: .tvos)], [.ok, nil, .ok]
        )
    }

}


fileprivate typealias BuildInfo = BuildIndex.Model.BuildInfo
fileprivate typealias RowIndex = BuildIndex.Model.BuildMatrix.RowIndex
