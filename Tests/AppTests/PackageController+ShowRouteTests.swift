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

class PackageController_ShowRouteTests: AppTestCase {

    typealias BuildDetails = (reference: Reference, platform: Build.Platform, swiftVersion: SwiftVersion, status: Build.Status)

    func test_History_query() throws {
        // setup
        Current.date = {
            Date.init(timeIntervalSince1970: 1608000588)  // Dec 15, 2020
        }
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg,
                       commitCount: 1433,
                       defaultBranch: "default",
                       firstCommitDate: .t0,
                       name: "bar",
                       owner: "foo").create(on: app.db).wait()
        try (0..<10).forEach {
            try Version(package: pkg,
                        latest: .defaultBranch,
                        reference: .branch("main")).create(on: app.db).wait()
            try Version(package: pkg,
                        latest: .release,
                        reference: .tag(.init($0, 0, 0))).create(on: app.db).wait()
        }
        // add pre-release and default branch - these should *not* be counted as releases
        try Version(package: pkg, reference: .branch("main")).create(on: app.db).wait()
        try Version(package: pkg, reference: .tag(.init(2, 0, 0, "beta2"), "2.0.0beta2")).create(on: app.db).wait()

        // MUT
        let record = try XCTUnwrap(PackageController.History.query(on: app.db, owner: "foo", repository: "bar").wait())

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

    func test_History_query_no_releases() throws {
        // setup
        Current.date = {
            Date.init(timeIntervalSince1970: 1608000588)  // Dec 15, 2020
        }
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg,
                       commitCount: 1433,
                       defaultBranch: "default",
                       firstCommitDate: .t0,
                       name: "bar",
                       owner: "foo").create(on: app.db).wait()

        // MUT
        let record = try XCTUnwrap(PackageController.History.query(on: app.db, owner: "foo", repository: "bar").wait())

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

    func test_History_Record_history() throws {
        Current.date = { .spiBirthday }
        do {  // all inputs set to non-nil values
            // setup
            let record = PackageController.History.Record(
                url: "url",
                defaultBranch: "main",
                firstCommitDate: .t0,
                commitCount: 7,
                releaseCount: 11
            )

            // MUT
            let hist = record.history()

            // validate
            XCTAssertEqual(
                hist,
                .init(since: "50 years",
                      commitCount: .init(label: "7 commits",
                                         url: "url/commits/main"),
                      releaseCount: .init(label: "11 releases",
                                          url: "url/releases"))
            )
        }
        do {  // test nil inputs
            XCTAssertNil(
                PackageController.History.Record(
                    url: "url",
                    defaultBranch: nil,
                    firstCommitDate: .t0,
                    commitCount: 7,
                    releaseCount: 11
                ).history()
            )
            XCTAssertNil(
                PackageController.History.Record(
                    url: "url",
                    defaultBranch: "main",
                    firstCommitDate: nil,
                    commitCount: 7,
                    releaseCount: 11
                ).history()
            )
        }
    }

    func test_ProductCount_query() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg,
                       defaultBranch: "main",
                       name: "bar",
                       owner: "foo").create(on: app.db).wait()
        do {
            let v = try Version(package: pkg,
                                latest: .defaultBranch,
                                reference: .branch("main"))
            try v.save(on: app.db).wait()
            try Product(version: v, type: .executable, name: "e1")
                .save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "l1")
                .save(on: app.db).wait()
            try Product(version: v, type: .library(.static), name: "l2")
                .save(on: app.db).wait()
        }
        do {  // decoy version
            let v = try Version(package: pkg,
                                latest: .release,
                                reference: .tag(1, 2, 3))
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "l3")
                .save(on: app.db).wait()
        }

        // MUT
        let res = try PackageController.ProductCount.query(on: app.db, owner: "foo", repository: "bar").wait()

        // validate
        XCTAssertEqual(res.filter(\.isExecutable).count, 1)
        XCTAssertEqual(res.filter(\.isLibrary).count, 2)
    }

    func test_swiftVersionBuildInfo() throws {
        // setup
        let builds: [PackageController.BuildsRoute.BuildInfo] = [
            .init(versionKind: .release, reference: .tag(1, 2, 3), buildId: .id0, swiftVersion: .v5_3, platform: .macosSpm, status: .ok),
            .init(versionKind: .release, reference: .tag(1, 2, 3), buildId: .id1, swiftVersion: .v5_2, platform: .ios, status: .failed)
        ]

        // MUT
        let res = PackageController.BuildInfo.swiftVersionBuildInfo(builds: builds)

        // validate
        XCTAssertEqual(res.stable?.referenceName, "1.2.3")
        XCTAssertEqual(res.stable?.results.v5_1,
                       .init(parameter: .v5_1, status: .unknown))
        XCTAssertEqual(res.stable?.results.v5_2,
                       .init(parameter: .v5_2, status: .incompatible))
        XCTAssertEqual(res.stable?.results.v5_3,
                       .init(parameter: .v5_3, status: .compatible))
        XCTAssertEqual(res.stable?.results.v5_4,
                       .init(parameter: .v5_4, status: .unknown))
        XCTAssertEqual(res.stable?.results.v5_5,
                       .init(parameter: .v5_5, status: .unknown))
        XCTAssertNil(res.beta)
        XCTAssertNil(res.latest)
    }

    func test_BuildInfo_query() throws {
        // setup
        do {
            let pkg = try savePackage(on: app.db, "1".url)
            try Repository(package: pkg,
                           defaultBranch: "main",
                           name: "bar",
                           owner: "foo").save(on: app.db).wait()
            let builds: [BuildDetails] = [
                (.branch("main"), .ios, .v5_5, .ok),
                (.branch("main"), .tvos, .v5_4, .failed),
                (.tag(1, 2, 3), .ios, .v5_5, .ok),
                (.tag(2, 0, 0, "b1"), .ios, .v5_5, .failed),
            ]
            try builds.forEach { b in
                let v = try App.Version(package: pkg,
                                        latest: b.reference.kind,
                                        packageName: "p1",
                                        reference: b.reference)
                try v.save(on: app.db).wait()
                try Build(version: v, platform: b.platform, status: b.status, swiftVersion: b.swiftVersion)
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
                (.branch("develop"), .ios, .v5_3, .ok),
            ]
            try builds.forEach { b in
                let v = try App.Version(package: pkg,
                                        latest: b.reference.kind,
                                        packageName: "p1",
                                        reference: b.reference)
                try v.save(on: app.db).wait()
                try Build(version: v, platform: b.platform, status: b.status, swiftVersion: b.swiftVersion)
                    .save(on: app.db).wait()
            }
        }

        // MUT
        let res = try PackageController.BuildInfo.query(on: app.db, owner: "foo", repository: "bar").wait()

        // validate
        // just test reference names and some details for `latest`
        // more detailed tests are covered in the lower level test
        XCTAssertEqual(res.platform.latest?.referenceName, "main")
        XCTAssertEqual(res.platform.latest?.results.ios.status, .compatible)
        XCTAssertEqual(res.platform.latest?.results.tvos.status, .incompatible)
        XCTAssertEqual(res.platform.latest?.results.watchos.status, .unknown)
        XCTAssertEqual(res.platform.stable?.referenceName, "1.2.3")
        XCTAssertEqual(res.platform.beta?.referenceName, "2.0.0-b1")
        XCTAssertEqual(res.swiftVersion.latest?.referenceName, "main")
        XCTAssertEqual(res.swiftVersion.latest?.results.v5_5.status, .compatible)
        XCTAssertEqual(res.swiftVersion.latest?.results.v5_4.status, .incompatible)
        XCTAssertEqual(res.swiftVersion.latest?.results.v5_3.status, .unknown)
        XCTAssertEqual(res.swiftVersion.stable?.referenceName, "1.2.3")
        XCTAssertEqual(res.swiftVersion.beta?.referenceName, "2.0.0-b1")
    }

    func test_ShowRoute_query() throws {
        // ensure ShowRoute.query is wired up correctly (detailed tests are elsewhere)
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "bar", owner: "foo")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch).save(on: app.db).wait()

        // MUT
        let (model, schema) = try PackageController.ShowRoute.query(on: app.db, owner: "foo", repository: "bar").wait()

        // validate
        XCTAssertEqual(model.repositoryName, "bar")
        XCTAssertEqual(schema.name, "bar")
    }

    func test_show() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch).save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package", afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
        })
    }

}
