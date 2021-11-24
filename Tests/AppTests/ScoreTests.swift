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


class ScoreTests: AppTestCase {
    
    func test_compute_input() throws {
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: false,
                                           licenseKind: .none,
                                           releaseCount: 0,
                                           likeCount: 0,
                                           isArchived: false,
                                           numberOfDependencies: 10_000)),
                       0)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: false,
                                           licenseKind: .incompatibleWithAppStore,
                                           releaseCount: 0,
                                           likeCount: 0,
                                           isArchived: false,
                                           numberOfDependencies: 10_000)),
                       3)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: false,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 0,
                                           likeCount: 0,
                                           isArchived: false,
                                           numberOfDependencies: 10_000)),
                       10)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 0,
                                           likeCount: 0,
                                           isArchived: false,
                                           numberOfDependencies: 10_000)),
                       20)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 10,
                                           likeCount: 0,
                                           isArchived: false,
                                           numberOfDependencies: 10_000)),
                       30)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 10,
                                           likeCount: 50,
                                           isArchived: false,
                                           numberOfDependencies: 10_000)),
                       40)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 10,
                                           likeCount: 50,
                                           isArchived: true,
                                           numberOfDependencies: 10_000)),
                       30)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 20,
                                           likeCount: 20_000,
                                           isArchived: false,
                                           numberOfDependencies: 10_000)),
                       77)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 20,
                                           likeCount: 20_000,
                                           isArchived: false,
                                           numberOfDependencies: 4)),
                       79)
        XCTAssertEqual(Score.compute(.init(supportsLatestSwiftVersion: true,
                                           licenseKind: .compatibleWithAppStore,
                                           releaseCount: 20,
                                           likeCount: 20_000,
                                           isArchived: false,
                                           numberOfDependencies: 2)),
                       82)
    }
    
    func test_compute_package_versions() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, defaultBranch: "default", stars: 10_000).save(on: app.db).wait()
        try Version(package: pkg,
                    reference: .branch("default"),
                    swiftVersions: ["5"].asSwiftVersions).save(on: app.db).wait()
        try (0..<20).forEach {
            try Version(package: pkg, reference: .tag(.init($0, 0, 0)))
                .save(on: app.db).wait()
        }
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()
        // update versions
        try updateLatestVersions(on: app.db, package: jpr).wait()
        let versions = try pkg.$versions.load(on: app.db)
            .map { pkg.versions }
            .wait()

        // MUT
        XCTAssertEqual(Score.compute(package: jpr, versions: versions), 72)
    }

}
