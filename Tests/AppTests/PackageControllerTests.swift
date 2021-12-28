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

class PackageControllerTests: AppTestCase {

    typealias BuildDetails = (id: Build.Id, reference: Reference, platform: Build.Platform, swiftVersion: SwiftVersion, status: Build.Status)

    func test_maintainerInfo() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch, packageName: "pkg")
            .save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/information-for-package-maintainers", afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
        })
    }

    func test_maintainerInfo_no_packageName() throws {
        // Ensure we display the page even if packageName is not set
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch, packageName: nil)
            .save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/information-for-package-maintainers", afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
        })
    }

    func test_BuildsRoute_BuildInfo_query() throws {
        // setup
        do {
            let pkg = try savePackage(on: app.db, "1".url)
            try Repository(package: pkg,
                           defaultBranch: "main",
                           name: "bar",
                           owner: "foo").save(on: app.db).wait()
            let builds: [BuildDetails] = [
                (.id0, .branch("main"), .ios, .v5_5, .ok),
                (.id1, .branch("main"), .tvos, .v5_4, .failed),
                (.id2, .tag(1, 2, 3), .ios, .v5_5, .ok),
                (.id3, .tag(2, 0, 0, "b1"), .ios, .v5_5, .failed),
            ]
            try builds.forEach { b in
                let v = try App.Version(package: pkg,
                                        latest: b.reference.kind,
                                        packageName: "p1",
                                        reference: b.reference)
                try v.save(on: app.db).wait()
                try Build(id: b.id, version: v, platform: b.platform, status: b.status, swiftVersion: b.swiftVersion)
                    .save(on: app.db).wait()
            }
        }
        do { // unrelated package and build
            let pkg = try savePackage(on: app.db, "2".url)
            try Repository(package: pkg,
                           defaultBranch: "main",
                           name: "bar2",
                           owner: "foo").save(on: app.db).wait()
            let builds: [BuildDetails] = [
                (.id4, .branch("develop"), .ios, .v5_3, .ok),
            ]
            try builds.forEach { b in
                let v = try App.Version(package: pkg,
                                        latest: b.reference.kind,
                                        packageName: "p1",
                                        reference: b.reference)
                try v.save(on: app.db).wait()
                try Build(id: b.id, version: v, platform: b.platform, status: b.status, swiftVersion: b.swiftVersion)
                    .save(on: app.db).wait()
            }
        }

        // MUT
        let builds = try PackageController.BuildsRoute.BuildInfo.query(on: app.db, owner: "foo", repository: "bar").wait()

        // validate
        XCTAssertEqual(
            builds.sorted { $0.buildId.uuidString < $1.buildId.uuidString },
            [
                .init(versionKind: .defaultBranch, reference: .branch("main"), buildId: .id0, swiftVersion: .v5_5, platform: .ios, status: .ok),
                .init(versionKind: .defaultBranch, reference: .branch("main"), buildId: .id1, swiftVersion: .v5_4, platform: .tvos, status: .failed),
                .init(versionKind: .release, reference: .tag(1, 2, 3), buildId: .id2, swiftVersion: .v5_5, platform: .ios, status: .ok),
                .init(versionKind: .preRelease, reference: .tag(2, 0, 0, "b1"), buildId: .id3, swiftVersion: .v5_5, platform: .ios, status: .failed),
            ].sorted { $0.buildId.uuidString < $1.buildId.uuidString }
        )
    }

    func test_BuildsRoute_query() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       defaultBranch: "main",
                       forks: 42,
                       license: .mit,
                       name: "bar",
                       owner: "foo",
                       stars: 17,
                       summary: "summary").save(on: app.db).wait()
        let v = try Version(package: pkg, latest: .defaultBranch, packageName: "pkg", reference: .branch("main"))
        try v.save(on: app.db).wait()
        try Build(id: .id0, version: v, platform: .ios, status: .ok, swiftVersion: .v5_5)
            .save(on: app.db).wait()

        // MUT
        let (pkgInfo, buildInfo) = try PackageController.BuildsRoute
            .query(on: app.db, owner: "foo", repository: "bar").wait()

        // validate
        XCTAssertEqual(pkgInfo, .init(packageName: "pkg",
                                      repositoryOwner: "foo",
                                      repositoryName: "bar"))
        XCTAssertEqual(buildInfo, [
            .init(versionKind: .defaultBranch,
                  reference: .branch("main"),
                  buildId: .id0,
                  swiftVersion: .v5_5,
                  platform: .ios,
                  status: .ok)
        ])
    }

    func test_BuildsRoute_query_no_builds() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       defaultBranch: "main",
                       forks: 42,
                       license: .mit,
                       name: "bar",
                       owner: "foo",
                       stars: 17,
                       summary: "summary").save(on: app.db).wait()
        // no builds and also no packageName set
        try Version(package: pkg, latest: .defaultBranch, packageName: nil).save(on: app.db).wait()

        // MUT
        let (pkgInfo, buildInfo) = try PackageController.BuildsRoute
            .query(on: app.db, owner: "foo", repository: "bar").wait()

        // validate
        XCTAssertEqual(pkgInfo, .init(packageName: nil,
                                      repositoryOwner: "foo",
                                      repositoryName: "bar"))
        XCTAssertEqual(buildInfo, [])

    }

}


extension Reference {
    var kind: Version.Kind {
        isBranch
        ? .defaultBranch
        : (isRelease ? .release : .preRelease)
    }
}
