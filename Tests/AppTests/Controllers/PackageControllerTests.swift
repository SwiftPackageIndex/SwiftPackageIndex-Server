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

    func test_ShowRoute_query() throws {
        XCTFail("implement")
    }

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
