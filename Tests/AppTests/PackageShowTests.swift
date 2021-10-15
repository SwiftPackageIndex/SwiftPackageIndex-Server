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

import XCTest


class PackageShowTests: AppTestCase {

    func test_releaseInfo() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, defaultBranch: "default").create(on: app.db).wait()
        let versions = [
            try Version(package: pkg, reference: .branch("branch")),
            try Version(package: pkg, commitDate: daysAgo(1), reference: .branch("default")),
            try Version(package: pkg, reference: .tag(.init(1, 2, 3))),
            try Version(package: pkg, commitDate: daysAgo(3), reference: .tag(.init(2, 1, 0))),
            try Version(package: pkg, commitDate: daysAgo(2), reference: .tag(.init(3, 0, 0, "beta"))),
        ]
        try versions.create(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()

        // MUT
        let info = PackageShow.releaseInfo(packageUrl: "1", versions: jpr.model.versions)

        // validate
        XCTAssertEqual(info.stable?.date, "3 days ago")
        XCTAssertEqual(info.beta?.date, "2 days ago")
        XCTAssertEqual(info.latest?.date, "1 day ago")
    }

    func test_releaseInfo_exclude_old_betas() throws {
        // Test to ensure that we don't publish a beta that's older than stable
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, defaultBranch: "default").create(on: app.db).wait()
        try [
            try Version(package: pkg, commitDate: daysAgo(1), reference: .branch("default")),
            try Version(package: pkg, commitDate: daysAgo(3), reference: .tag(.init(2, 1, 0))),
            try Version(package: pkg, commitDate: daysAgo(2), reference: .tag(.init(2, 0, 0, "beta"))),
        ].create(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        let versions = try pkg.$versions.load(on: app.db)
            .map { pkg.versions }
            .wait()

        // MUT
        let info = PackageShow.releaseInfo(packageUrl: "1", versions: versions)

        // validate
        XCTAssertEqual(info.stable?.date, "3 days ago")
        XCTAssertEqual(info.beta, nil)
        XCTAssertEqual(info.latest?.date, "1 day ago")
    }

    func test_releaseInfo_nonEager() throws {
        // ensure non-eager access does not fatalError
        let pkg = try savePackage(on: app.db, "1")
        let versions = [
            try Version(package: pkg, reference: .branch("default")),
        ]
        try versions.create(on: app.db).wait()

        // MUT / validate
        XCTAssertNoThrow(PackageShow.releaseInfo(packageUrl: "1", versions: versions))
    }

}
