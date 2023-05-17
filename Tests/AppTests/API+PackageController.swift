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


class API_PackageControllerTests: AppTestCase {

    typealias BuildDetails = (reference: Reference, platform: Build.Platform, swiftVersion: SwiftVersion, status: Build.Status)

    func test_History_query() async throws {
        // setup
        Current.date = {
            Date.init(timeIntervalSince1970: 1608000588)  // Dec 15, 2020
        }
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg,
                             commitCount: 1433,
                             defaultBranch: "default",
                             firstCommitDate: .t0,
                             name: "bar",
                             owner: "foo").create(on: app.db)
        for idx in (0..<10) {
            try await Version(package: pkg,
                              latest: .defaultBranch,
                              reference: .branch("main")).create(on: app.db)
            try await Version(package: pkg,
                              latest: .release,
                              reference: .tag(.init(idx, 0, 0))).create(on: app.db)
        }
        // add pre-release and default branch - these should *not* be counted as releases
        try await Version(package: pkg, reference: .branch("main")).create(on: app.db)
        try await Version(package: pkg, reference: .tag(.init(2, 0, 0, "beta2"), "2.0.0beta2")).create(on: app.db)

        // MUT
        let record = try await API.PackageController.History.query(on: app.db, owner: "foo", repository: "bar").unwrap()

        // validate
        XCTAssertEqual(
            record,
            .init(url: "1",
                  defaultBranch: "default",
                  firstCommitDate: .t0,
                  commitCount: 1433,
                  releaseCount: 10)
        )
    }

    func test_History_query_no_releases() async throws {
        // setup
        Current.date = {
            Date.init(timeIntervalSince1970: 1608000588)  // Dec 15, 2020
        }
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg,
                             commitCount: 1433,
                             defaultBranch: "default",
                             firstCommitDate: .t0,
                             name: "bar",
                             owner: "foo").create(on: app.db)

        // MUT
        let record = try await API.PackageController.History.query(on: app.db, owner: "foo", repository: "bar").unwrap()

        // validate
        XCTAssertEqual(
            record,
            .init(url: "1",
                  defaultBranch: "default",
                  firstCommitDate: .t0,
                  commitCount: 1433,
                  releaseCount: 0)
        )
    }

    func test_History_Record_historyModel() throws {
        do {  // all inputs set to non-nil values
            // setup
            let record = API.PackageController.History.Record(
                url: "url",
                defaultBranch: "main",
                firstCommitDate: .t0,
                commitCount: 7,
                releaseCount: 11
            )

            // MUT
            let hist = record.historyModel()

            // validate
            XCTAssertEqual(
                hist,
                .init(createdAt: .t0,
                      commitCount: 7,
                      commitCountURL: "url/commits/main",
                      releaseCount: 11,
                      releaseCountURL: "url/releases")
            )
        }
        do {  // test nil inputs
            XCTAssertNil(
                API.PackageController.History.Record(
                    url: "url",
                    defaultBranch: nil,
                    firstCommitDate: .t0,
                    commitCount: 7,
                    releaseCount: 11
                ).historyModel()
            )
            XCTAssertNil(
                API.PackageController.History.Record(
                    url: "url",
                    defaultBranch: "main",
                    firstCommitDate: nil,
                    commitCount: 7,
                    releaseCount: 11
                ).historyModel()
            )
        }
    }

    func test_ProductCount_query() async throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg,
                             defaultBranch: "main",
                             name: "bar",
                             owner: "foo").create(on: app.db)
        do {
            let v = try Version(package: pkg,
                                latest: .defaultBranch,
                                reference: .branch("main"))
            try await v.save(on: app.db)
            try await Product(version: v, type: .executable, name: "e1")
                .save(on: app.db)
            try await Product(version: v, type: .library(.automatic), name: "l1")
                .save(on: app.db)
            try await Product(version: v, type: .library(.static), name: "l2")
                .save(on: app.db)
        }
        do {  // decoy version
            let v = try Version(package: pkg,
                                latest: .release,
                                reference: .tag(1, 2, 3))
            try await v.save(on: app.db)
            try await Product(version: v, type: .library(.automatic), name: "l3")
                .save(on: app.db)
        }

        // MUT
        let res = try await API.PackageController.ProductCount.query(on: app.db, owner: "foo", repository: "bar")

        // validate
        XCTAssertEqual(res.filter(\.isExecutable).count, 1)
        XCTAssertEqual(res.filter(\.isLibrary).count, 2)
    }

    func test_platformBuildResults() throws {
        // Test build success reporting - we take any success across swift versions
        // as a success for a particular platform
        // setup
        func makeBuild(_ status: Build.Status, _ platform: Build.Platform, _ version: SwiftVersion) -> PackageController.BuildsRoute.BuildInfo {
            .init(versionKind: .defaultBranch, reference: .branch("main"), buildId: UUID(), swiftVersion: version, platform: platform, status: status)
        }

        let builds = [
            // ios - failed
            makeBuild(.failed, .ios, .v5_6),
            makeBuild(.failed, .ios, .v5_5),
            // macos - failed
            makeBuild(.failed, .macosSpm, .v5_6),
            makeBuild(.failed, .macosXcodebuild, .v5_5),
            // tvos - no data - unknown
            // watchos - ok
            makeBuild(.failed, .watchos, .v5_6),
            makeBuild(.ok, .watchos, .v5_5),
            // unrelated build
            .init(versionKind: .release, reference: .tag(1, 2, 3), buildId: .id0, swiftVersion: .v5_6, platform: .ios, status: .ok),
        ]

        // MUT
        let res = API.PackageController.BuildInfo
            .platformBuildResults(builds: builds, kind: .defaultBranch)

        // validate
        XCTAssertEqual(res?.referenceName, "main")
        XCTAssertEqual(res?.results.ios, .init(parameter: .ios, status: .incompatible))
        XCTAssertEqual(res?.results.macos, .init(parameter: .macos, status: .incompatible))
        XCTAssertEqual(res?.results.tvos, .init(parameter: .tvos, status: .unknown))
        XCTAssertEqual(res?.results.watchos, .init(parameter: .watchos, status: .compatible))
    }

    func test_swiftVersionBuildResults() throws {
        // Test build success reporting - we take any success across platforms
        // as a success for a particular x.y swift version (4.2, 5.0, etc, i.e.
        // ignoring swift patch versions)
        // setup
        func makeBuild(_ status: Build.Status, _ platform: Build.Platform, _ version: SwiftVersion) -> PackageController.BuildsRoute.BuildInfo {
            .init(versionKind: .defaultBranch, reference: .branch("main"), buildId: UUID(), swiftVersion: version, platform: platform, status: status)
        }

        let builds = [
            // 5.5 - failed
            makeBuild(.failed, .ios, .v5_5),
            makeBuild(.failed, .macosXcodebuild, .v5_5),
            // 5.6 - no data - unknown
            // 5.7 - ok
            makeBuild(.ok, .macosXcodebuild, .v5_7),
            // 5.8 - ok
            makeBuild(.failed, .ios, .v5_8),
            makeBuild(.ok, .macosXcodebuild, .v5_8),
            // unrelated release version build (we're testing defaultBranch builds)
            .init(versionKind: .release, reference: .tag(1, 2, 3), buildId: .id0, swiftVersion: .v5_8, platform: .ios, status: .failed),
        ]

        // MUT
        let res = API.PackageController.BuildInfo
            .swiftVersionBuildResults(builds: builds, kind: .defaultBranch)

        // validate
        XCTAssertEqual(res?.referenceName, "main")
        XCTAssertEqual(res?.results.v5_5, .init(parameter: .v5_5, status: .incompatible))
        XCTAssertEqual(res?.results.v5_6, .init(parameter: .v5_6, status: .unknown))
        XCTAssertEqual(res?.results.v5_7, .init(parameter: .v5_7, status: .compatible))
        XCTAssertEqual(res?.results.v5_8, .init(parameter: .v5_8, status: .compatible))
    }

    func test_platformBuildInfo() throws {
        // setup
        let builds: [PackageController.BuildsRoute.BuildInfo] = [
            .init(versionKind: .release, reference: .tag(1, 2, 3), buildId: .id0, swiftVersion: .v5_6, platform: .macosSpm, status: .ok),
            .init(versionKind: .release, reference: .tag(1, 2, 3), buildId: .id1, swiftVersion: .v5_6, platform: .tvos, status: .failed)
        ]

        // MUT
        let res = API.PackageController.BuildInfo.platformBuildInfo(builds: builds)

        // validate
        XCTAssertEqual(res?.stable?.referenceName, "1.2.3")
        XCTAssertEqual(res?.stable?.results.ios,
                       .init(parameter: .ios, status: .unknown))
        XCTAssertEqual(res?.stable?.results.macos,
                       .init(parameter: .macos, status: .compatible))
        XCTAssertEqual(res?.stable?.results.tvos,
                       .init(parameter: .tvos, status: .incompatible))
        XCTAssertEqual(res?.stable?.results.watchos,
                       .init(parameter: .watchos, status: .unknown))
        XCTAssertNil(res?.beta)
        XCTAssertNil(res?.latest)
    }

    func test_swiftVersionBuildInfo() throws {
        // setup
        let builds: [PackageController.BuildsRoute.BuildInfo] = [
            .init(versionKind: .release, reference: .tag(1, 2, 3), buildId: .id0, swiftVersion: .v5_7, platform: .macosSpm, status: .ok),
            .init(versionKind: .release, reference: .tag(1, 2, 3), buildId: .id1, swiftVersion: .v5_6, platform: .ios, status: .failed)
        ]

        // MUT
        let res = API.PackageController.BuildInfo.swiftVersionBuildInfo(builds: builds)

        // validate
        XCTAssertEqual(res?.stable?.referenceName, "1.2.3")
        XCTAssertEqual(res?.stable?.results.v5_5,
                       .init(parameter: .v5_5, status: .unknown))
        XCTAssertEqual(res?.stable?.results.v5_6,
                       .init(parameter: .v5_6, status: .incompatible))
        XCTAssertEqual(res?.stable?.results.v5_7,
                       .init(parameter: .v5_7, status: .compatible))
        XCTAssertEqual(res?.stable?.results.v5_8,
                       .init(parameter: .v5_8, status: .unknown))
        XCTAssertNil(res?.beta)
        XCTAssertNil(res?.latest)
    }

    func test_BuildInfo_query() async throws {
        // setup
        do {
            let pkg = try savePackage(on: app.db, "1".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 name: "bar",
                                 owner: "foo").save(on: app.db)
            let builds: [BuildDetails] = [
                (.branch("main"), .ios, .v5_7, .ok),
                (.branch("main"), .tvos, .v5_6, .failed),
                (.tag(1, 2, 3), .ios, .v5_7, .ok),
                (.tag(2, 0, 0, "b1"), .ios, .v5_7, .failed),
            ]
            for b in builds {
                let v = try App.Version(package: pkg,
                                        latest: b.reference.kind,
                                        packageName: "p1",
                                        reference: b.reference)
                try await v.save(on: app.db)
                try await Build(version: v, platform: b.platform, status: b.status, swiftVersion: b.swiftVersion)
                    .save(on: app.db)
            }
        }
        do { // unrelated package and build
            let pkg = try savePackage(on: app.db, "2".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 name: "bar2",
                                 owner: "foo").save(on: app.db)
            let builds: [BuildDetails] = [
                (.branch("develop"), .ios, .v5_5, .ok),
            ]
            for b in builds {
                let v = try App.Version(package: pkg,
                                        latest: b.reference.kind,
                                        packageName: "p1",
                                        reference: b.reference)
                try await v.save(on: app.db)
                try await Build(version: v, platform: b.platform, status: b.status, swiftVersion: b.swiftVersion)
                    .save(on: app.db)
            }
        }

        // MUT
        let res = try await API.PackageController.BuildInfo.query(on: app.db, owner: "foo", repository: "bar")

        // validate
        // just test reference names and some details for `latest`
        // more detailed tests are covered in the lower level test
        XCTAssertEqual(res.platform?.latest?.referenceName, "main")
        XCTAssertEqual(res.platform?.latest?.results.ios.status, .compatible)
        XCTAssertEqual(res.platform?.latest?.results.tvos.status, .incompatible)
        XCTAssertEqual(res.platform?.latest?.results.watchos.status, .unknown)
        XCTAssertEqual(res.platform?.stable?.referenceName, "1.2.3")
        XCTAssertEqual(res.platform?.beta?.referenceName, "2.0.0-b1")
        XCTAssertEqual(res.swiftVersion?.latest?.referenceName, "main")
        XCTAssertEqual(res.swiftVersion?.latest?.results.v5_7.status, .compatible)
        XCTAssertEqual(res.swiftVersion?.latest?.results.v5_6.status, .incompatible)
        XCTAssertEqual(res.swiftVersion?.latest?.results.v5_5.status, .unknown)
        XCTAssertEqual(res.swiftVersion?.stable?.referenceName, "1.2.3")
        XCTAssertEqual(res.swiftVersion?.beta?.referenceName, "2.0.0-b1")
    }

    func test_GetRoute_query() async throws {
        // ensure GetRoute.query is wired up correctly (detailed tests are elsewhere)
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg, name: "bar", owner: "foo")
            .save(on: app.db)
        try await Version(package: pkg, latest: .defaultBranch).save(on: app.db)

        // MUT
        let (model, schema) = try await API.PackageController.GetRoute.query(on: app.db, owner: "foo", repository: "bar")

        // validate
        XCTAssertEqual(model.repositoryName, "bar")
        XCTAssertEqual(schema.name, "bar")
    }

}
