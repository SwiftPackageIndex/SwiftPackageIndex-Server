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

import XCTest


class PackageShowTests: AppTestCase {

    typealias PackageResult = PackageController.PackageResult

    func test_releaseInfo() async throws {
        // setup
        Current.date = { .t0 }
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg,
                             defaultBranch: "default",
                             name: "bar",
                             owner: "foo").save(on: app.db)
        try await [
            try Version(package: pkg,
                        latest: nil,
                        reference: .branch("branch")),
            try Version(package: pkg,
                        commitDate: daysAgo(1),
                        latest: .defaultBranch,
                        reference: .branch("default")),
            try Version(package: pkg,
                        latest: nil,
                        reference: .tag(.init(1, 2, 3))),
            try Version(package: pkg,
                        commitDate: daysAgo(3),
                        latest: .release,
                        reference: .tag(.init(2, 1, 0))),
            try Version(package: pkg,
                        commitDate: daysAgo(2),
                        latest: .preRelease,
                        reference: .tag(.init(3, 0, 0, "beta"))),
        ].save(on: app.db)
        let pr = try await PackageResult.query(on: app.db,
                                               owner: "foo",
                                               repository: "bar")

        // MUT
        let info = PackageShow.releaseInfo(
            packageUrl: "1",
            defaultBranchVersion: pr.defaultBranchVersion,
            releaseVersion: pr.releaseVersion,
            preReleaseVersion: pr.preReleaseVersion
        )

        // validate
        XCTAssertEqual(info.stable?.date, "3 days ago")
        XCTAssertEqual(info.beta?.date, "2 days ago")
        XCTAssertEqual(info.latest?.date, "1 day ago")
    }

    func test_releaseInfo_exclude_non_latest() async throws {
        // Test to ensure that we don't include versions with `latest IS NULL`
        // setup
        Current.date = { .t0 }
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg,
                             defaultBranch: "default",
                             name: "bar",
                             owner: "foo").save(on: app.db)
        try await [
            try Version(package: pkg,
                        commitDate: daysAgo(1),
                        latest: .defaultBranch,
                        reference: .branch("default")),
            try Version(package: pkg,
                        commitDate: daysAgo(3),
                        latest: .release,
                        reference: .tag(.init(2, 1, 0))),
            try Version(package: pkg,
                        commitDate: daysAgo(2),
                        latest: nil,
                        reference: .tag(.init(2, 0, 0, "beta"))),
        ].save(on: app.db)
        let pr = try await PackageResult.query(on: app.db,
                                               owner: "foo",
                                               repository: "bar")

        // MUT
        let info = PackageShow.releaseInfo(
            packageUrl: "1",
            defaultBranchVersion: pr.defaultBranchVersion,
            releaseVersion: pr.releaseVersion,
            preReleaseVersion: pr.preReleaseVersion
        )

        // validate
        XCTAssertEqual(info.stable?.date, "3 days ago")
        XCTAssertEqual(info.beta, nil)
        XCTAssertEqual(info.latest?.date, "1 day ago")
    }

}
