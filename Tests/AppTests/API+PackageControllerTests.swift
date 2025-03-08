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

import Dependencies
import Testing
import Vapor


extension AllTests.API_PackageControllerTests {

    typealias BuildDetails = (reference: Reference, platform: Build.Platform, swiftVersion: SwiftVersion, status: Build.Status)

    func History_query() async throws {
        try await withDependencies {
            $0.date.now = .december15_2020
        } operation: {
            try await withApp { app in
                let pkg = try await savePackage(on: app.db, "1")
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
                #expect(
                    record == .init(url: "1",
                                    defaultBranch: "default",
                                    firstCommitDate: .t0,
                                    commitCount: 1433,
                                    releaseCount: 10)
                )
            }
        }
    }

    func History_query_no_releases() async throws {
        try await withDependencies {
            $0.date.now = .december15_2020
        } operation: {
            try await withApp { app in
                let pkg = try await savePackage(on: app.db, "1")
                try await Repository(package: pkg,
                                     commitCount: 1433,
                                     defaultBranch: "default",
                                     firstCommitDate: .t0,
                                     name: "bar",
                                     owner: "foo").create(on: app.db)

                // MUT
                let record = try await API.PackageController.History.query(on: app.db, owner: "foo", repository: "bar").unwrap()

                // validate
                #expect(
                    record == .init(url: "1",
                                    defaultBranch: "default",
                                    firstCommitDate: .t0,
                                    commitCount: 1433,
                                    releaseCount: 0)
                )
            }
        }
    }

    @Test func History_Record_historyModel() throws {
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
            #expect(
                hist == .init(createdAt: .t0,
                      commitCount: 7,
                      commitCountURL: "url/commits/main",
                      releaseCount: 11,
                      releaseCountURL: "url/releases")
            )
        }
        do {  // test nil inputs
            #expect(
                API.PackageController.History.Record(
                    url: "url",
                    defaultBranch: nil,
                    firstCommitDate: .t0,
                    commitCount: 7,
                    releaseCount: 11
                ).historyModel() == nil
            )
            #expect(
                API.PackageController.History.Record(
                    url: "url",
                    defaultBranch: "main",
                    firstCommitDate: nil,
                    commitCount: 7,
                    releaseCount: 11
                ).historyModel() == nil
            )
        }
    }

    @Test func ProductCount_query() async throws {
        // setup
        try await withApp { app in
            let pkg = try await savePackage(on: app.db, "1")
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
            let res = try await API.PackageController.Product.query(on: app.db, owner: "foo", repository: "bar")

            // validate
            #expect(res.filter(\.1.isExecutable).count == 1)
            #expect(res.filter(\.1.isLibrary).count == 2)
        }
    }

    @Test func platformBuildResults() throws {
        // Test build success reporting - we take any success across swift versions
        // as a success for a particular platform
        // setup
        func makeBuild(_ status: Build.Status, _ platform: Build.Platform, _ version: SwiftVersion) -> PackageController.BuildsRoute.BuildInfo {
            .init(versionKind: .defaultBranch, reference: .branch("main"), buildId: UUID(), swiftVersion: version, platform: platform, status: status)
        }

        let builds = [
            // ios - failed
            makeBuild(.failed, .iOS, .v2),
            makeBuild(.failed, .iOS, .v1),
            // macos - failed
            makeBuild(.failed, .macosSpm, .v2),
            makeBuild(.failed, .macosXcodebuild, .v1),
            // tvos - no data - unknown
            // watchos - ok
            makeBuild(.failed, .watchOS, .v2),
            makeBuild(.ok, .watchOS, .v1),
            // unrelated build
            .init(versionKind: .release, reference: .tag(1, 2, 3), buildId: .id0, swiftVersion: .v2, platform: .iOS, status: .ok),
        ]

        // MUT
        let res = API.PackageController.BuildInfo
            .platformBuildResults(builds: builds, kind: .defaultBranch)

        // validate
        #expect(res?.referenceName == "main")
        #expect(res?.results[.iOS] == .incompatible)
        #expect(res?.results[.macOS] == .incompatible)
        #expect(res?.results[.tvOS] == .unknown)
        #expect(res?.results[.watchOS] == .compatible)
    }

    @Test func swiftVersionBuildResults() throws {
        // Test build success reporting - we take any success across platforms
        // as a success for a particular x.y swift version (4.2, 5.0, etc, i.e.
        // ignoring swift patch versions)
        // setup
        func makeBuild(_ status: Build.Status, _ platform: Build.Platform, _ version: SwiftVersion) -> PackageController.BuildsRoute.BuildInfo {
            .init(versionKind: .defaultBranch, reference: .branch("main"), buildId: UUID(), swiftVersion: version, platform: platform, status: status)
        }

        let builds = [
            // v1 - failed
            makeBuild(.failed, .iOS, .v1),
            makeBuild(.failed, .macosXcodebuild, .v1),
            // v2 - no data - unknown
            // v3 - ok
            makeBuild(.ok, .macosXcodebuild, .v3),
            // v4 - ok
            makeBuild(.failed, .iOS, .v4),
            makeBuild(.ok, .macosXcodebuild, .v4),
            // unrelated release version build (we're testing defaultBranch builds)
            .init(versionKind: .release, reference: .tag(1, 2, 3), buildId: .id0, swiftVersion: .v4, platform: .iOS, status: .failed),
        ]

        // MUT
        let res = API.PackageController.BuildInfo
            .swiftVersionBuildResults(builds: builds, kind: .defaultBranch)

        // validate
        #expect(res?.referenceName == "main")
        #expect(res?.results[.v1] == .incompatible)
        #expect(res?.results[.v2] == .unknown)
        #expect(res?.results[.v3] == .compatible)
        #expect(res?.results[.v4] == .compatible)
    }

    @Test func platformBuildInfo() throws {
        // setup
        let builds: [PackageController.BuildsRoute.BuildInfo] = [
            .init(versionKind: .release, reference: .tag(1, 2, 3), buildId: .id0, swiftVersion: .v2, platform: .macosSpm, status: .ok),
            .init(versionKind: .release, reference: .tag(1, 2, 3), buildId: .id1, swiftVersion: .v2, platform: .tvOS, status: .failed)
        ]

        // MUT
        let res = API.PackageController.BuildInfo.platformBuildInfo(builds: builds)

        // validate
        #expect(res?.stable?.referenceName == "1.2.3")
        #expect(res?.stable?.results[.iOS] == .unknown)
        #expect(res?.stable?.results[.macOS] == .compatible)
        #expect(res?.stable?.results[.tvOS] == .incompatible)
        #expect(res?.stable?.results[.watchOS] == .unknown)
        #expect(res?.beta == nil)
        #expect(res?.latest == nil)
    }

    @Test func swiftVersionBuildInfo() throws {
        // setup
        let builds: [PackageController.BuildsRoute.BuildInfo] = [
            .init(versionKind: .release, reference: .tag(1, 2, 3), buildId: .id0, swiftVersion: .v3, platform: .macosSpm, status: .ok),
            .init(versionKind: .release, reference: .tag(1, 2, 3), buildId: .id1, swiftVersion: .v2, platform: .iOS, status: .failed)
        ]

        // MUT
        let res = API.PackageController.BuildInfo.swiftVersionBuildInfo(builds: builds)

        // validate
        #expect(res?.stable?.referenceName == "1.2.3")
        #expect(res?.stable?.results[.v1] == .unknown)
        #expect(res?.stable?.results[.v2] == .incompatible)
        #expect(res?.stable?.results[.v3] == .compatible)
        #expect(res?.stable?.results[.v4] == .unknown)
        #expect(res?.beta == nil)
        #expect(res?.latest == nil)
    }

    @Test func BuildInfo_query() async throws {
        // setup
        try await withApp { app in
            do {
                let pkg = try await savePackage(on: app.db, "1".url)
                try await Repository(package: pkg,
                                     defaultBranch: "main",
                                     name: "bar",
                                     owner: "foo").save(on: app.db)
                let builds: [BuildDetails] = [
                    (.branch("main"), .iOS, .v3, .ok),
                    (.branch("main"), .tvOS, .v2, .failed),
                    (.tag(1, 2, 3), .iOS, .v3, .ok),
                    (.tag(2, 0, 0, "b1"), .iOS, .v3, .failed),
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
                let pkg = try await savePackage(on: app.db, "2".url)
                try await Repository(package: pkg,
                                     defaultBranch: "main",
                                     name: "bar2",
                                     owner: "foo").save(on: app.db)
                let builds: [BuildDetails] = [
                    (.branch("develop"), .iOS, .v1, .ok),
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
            let platform = try #require(res.platform)
            #expect(platform.latest?.referenceName == "main")
            #expect(platform.latest?.results[.iOS] == .compatible)
            #expect(platform.latest?.results[.tvOS] == .incompatible)
            #expect(platform.latest?.results[.watchOS] == .unknown)
            #expect(platform.stable?.referenceName == "1.2.3")
            #expect(platform.beta?.referenceName == "2.0.0-b1")
            let swiftVersion = try #require(res.swiftVersion)
            #expect(swiftVersion.latest?.referenceName == "main")
            #expect(swiftVersion.latest?.results[.v5_10] == .compatible)
            #expect(swiftVersion.latest?.results[.v5_9] == .incompatible)
            #expect(swiftVersion.latest?.results[.v5_8] == .unknown)
            #expect(swiftVersion.stable?.referenceName == "1.2.3")
            #expect(swiftVersion.beta?.referenceName == "2.0.0-b1")
        }
    }

    @Test func GetRoute_query() async throws {
        // ensure GetRoute.query is wired up correctly (detailed tests are elsewhere)
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1")
            try await Repository(package: pkg, name: "bar", owner: "foo")
                .save(on: app.db)
            try await Version(package: pkg, latest: .defaultBranch).save(on: app.db)

            // MUT
            let (model, schema) = try await API.PackageController.GetRoute.query(on: app.db, owner: "foo", repository: "bar")

            // validate
            #expect(model.repositoryName == "bar")
            #expect(schema.name == "bar")
        }
    }

}


private extension Date {
    static var december15_2020: Self { .init(timeIntervalSince1970: 1608000588) }
}
