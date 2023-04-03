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

class PackageController_BuildsRouteTests: AppTestCase {

    typealias BuildDetails = (id: Build.Id, reference: Reference, platform: Build.Platform, swiftVersion: SwiftVersion, status: Build.Status, docStatus: DocUpload.Status?)

    func test_BuildInfo_query() async throws {
        // setup
        do {
            let pkg = try savePackage(on: app.db, "1".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 name: "bar",
                                 owner: "foo").save(on: app.db)
            let builds: [BuildDetails] = [
                (.id0, .branch("main"), .ios, .v5_6, .ok, .ok),
                (.id1, .branch("main"), .tvos, .v5_5, .failed, nil),
                (.id2, .tag(1, 2, 3), .ios, .v5_6, .ok, nil),
                (.id3, .tag(2, 0, 0, "b1"), .ios, .v5_6, .failed, nil),
            ]
            for b in builds {
                let v = try App.Version(package: pkg,
                                        latest: b.reference.kind,
                                        packageName: "p1",
                                        reference: b.reference)
                try await v.save(on: app.db)
                let build = try Build(id: b.id, version: v, platform: b.platform, status: b.status, swiftVersion: b.swiftVersion)
                try await build.save(on: app.db)
                if let docStatus = b.docStatus {
                    let d = DocUpload(id: .init(), status: docStatus)
                    try await d.attach(to: build, on: app.db)
                }
            }
        }
        do { // unrelated package and build
            let pkg = try savePackage(on: app.db, "2".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 name: "bar2",
                                 owner: "foo").save(on: app.db)
            let builds: [BuildDetails] = [
                (.id4, .branch("develop"), .ios, .v5_8, .ok, nil),
            ]
            for b in builds {
                let v = try App.Version(package: pkg,
                                        latest: b.reference.kind,
                                        packageName: "p1",
                                        reference: b.reference)
                try await v.save(on: app.db)
                try await Build(id: b.id, version: v, platform: b.platform, status: b.status, swiftVersion: b.swiftVersion)
                    .save(on: app.db)
            }
        }

        // MUT
        let builds = try await PackageController.BuildsRoute.BuildInfo.query(on: app.db, owner: "foo", repository: "bar")

        // validate
        XCTAssertEqual(
            builds.sorted { $0.buildId.uuidString < $1.buildId.uuidString },
            [
                .init(versionKind: .defaultBranch, reference: .branch("main"), buildId: .id0, swiftVersion: .v5_6, platform: .ios, status: .ok, docStatus: .ok),
                .init(versionKind: .defaultBranch, reference: .branch("main"), buildId: .id1, swiftVersion: .v5_5, platform: .tvos, status: .failed),
                .init(versionKind: .release, reference: .tag(1, 2, 3), buildId: .id2, swiftVersion: .v5_6, platform: .ios, status: .ok),
                .init(versionKind: .preRelease, reference: .tag(2, 0, 0, "b1"), buildId: .id3, swiftVersion: .v5_6, platform: .ios, status: .failed),
            ].sorted { $0.buildId.uuidString < $1.buildId.uuidString }
        )
    }

    func test_query() async throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try await Repository(package: pkg,
                             defaultBranch: "main",
                             forks: 42,
                             license: .mit,
                             name: "bar",
                             owner: "foo",
                             stars: 17,
                             summary: "summary").save(on: app.db)
        let v = try Version(package: pkg, latest: .defaultBranch, packageName: "pkg", reference: .branch("main"))
        try await v.save(on: app.db)
        try await Build(id: .id0, version: v, platform: .ios, status: .ok, swiftVersion: .v5_5)
            .save(on: app.db)

        // MUT
        let (pkgInfo, buildInfo) = try await PackageController.BuildsRoute
            .query(on: app.db, owner: "foo", repository: "bar")

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

    func test_query_no_builds() async throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try await Repository(package: pkg,
                             defaultBranch: "main",
                             forks: 42,
                             license: .mit,
                             name: "bar",
                             owner: "foo",
                             stars: 17,
                             summary: "summary").save(on: app.db)
        // no builds and also no packageName set
        try await Version(package: pkg, latest: .defaultBranch, packageName: nil).save(on: app.db)

        // MUT
        let (pkgInfo, buildInfo) = try await PackageController.BuildsRoute
            .query(on: app.db, owner: "foo", repository: "bar")

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
