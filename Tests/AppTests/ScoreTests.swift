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
        XCTAssertEqual(Score.compute(.init(licenseKind: .none,
                                           releaseCount: 0,
                                           likeCount: 0,
                                           isArchived: false,
                                           numberOfDependencies: nil,
                                           hasDocumentation: false)),
                       20)
        XCTAssertEqual(Score.compute(.init(licenseKind: .incompatibleWithAppStore,
                                           releaseCount: 0,
                                           likeCount: 0,
                                           isArchived: false,
                                           numberOfDependencies: nil,
                                           hasDocumentation: false)),
                       23)
        XCTAssertEqual(Score.compute(.init(licenseKind: .compatibleWithAppStore,
                                           releaseCount: 0,
                                           likeCount: 0,
                                           isArchived: false,
                                           numberOfDependencies: nil,
                                           hasDocumentation: false)),
                       30)
        XCTAssertEqual(Score.compute(.init(licenseKind: .compatibleWithAppStore,
                                           releaseCount: 10,
                                           likeCount: 0,
                                           isArchived: false,
                                           numberOfDependencies: nil,
                                           hasDocumentation: false)),
                       40)
        XCTAssertEqual(Score.compute(.init(licenseKind: .compatibleWithAppStore,
                                           releaseCount: 10,
                                           likeCount: 50,
                                           isArchived: false,
                                           numberOfDependencies: nil,
                                           hasDocumentation: false)),
                       50)
        XCTAssertEqual(Score.compute(.init(licenseKind: .compatibleWithAppStore,
                                           releaseCount: 10,
                                           likeCount: 50,
                                           isArchived: true,
                                           numberOfDependencies: nil,
                                           hasDocumentation: false)),
                       30)
        XCTAssertEqual(Score.compute(.init(licenseKind: .compatibleWithAppStore,
                                           releaseCount: 20,
                                           likeCount: 20_000,
                                           isArchived: false,
                                           numberOfDependencies: nil,
                                           hasDocumentation: false)),
                       87)
        XCTAssertEqual(Score.compute(.init(licenseKind: .compatibleWithAppStore,
                                           releaseCount: 20,
                                           likeCount: 20_000,
                                           isArchived: false,
                                           numberOfDependencies: 4,
                                           hasDocumentation: false)),
                       89)
        XCTAssertEqual(Score.compute(.init(licenseKind: .compatibleWithAppStore,
                                           releaseCount: 20,
                                           likeCount: 20_000,
                                           isArchived: false,
                                           numberOfDependencies: 2,
                                           hasDocumentation: false)),
                       92)
        XCTAssertEqual(Score.compute(.init(licenseKind: .compatibleWithAppStore,
                                           releaseCount: 20,
                                           likeCount: 20_000,
                                           isArchived: false,
                                           numberOfDependencies: 2,
                                           lastActivityAt: Current.date().addingDays(-400),
                                           hasDocumentation: false)),
                       92)
        XCTAssertEqual(Score.compute(.init(licenseKind: .compatibleWithAppStore,
                                           releaseCount: 20,
                                           likeCount: 20_000,
                                           isArchived: false,
                                           numberOfDependencies: 2,
                                           lastActivityAt: Current.date().addingDays(-300),
                                           hasDocumentation: false)),
                       97)
        XCTAssertEqual(Score.compute(.init(licenseKind: .compatibleWithAppStore,
                                           releaseCount: 20,
                                           likeCount: 20_000,
                                           isArchived: false,
                                           numberOfDependencies: 2,
                                           lastActivityAt: Current.date().addingDays(-100),
                                           hasDocumentation: false)),
                       102)
        XCTAssertEqual(Score.compute(.init(licenseKind: .compatibleWithAppStore,
                                           releaseCount: 20,
                                           likeCount: 20_000,
                                           isArchived: false,
                                           numberOfDependencies: 2,
                                           lastActivityAt: Current.date().addingDays(-10),
                                           hasDocumentation: false)),
                       107)
        XCTAssertEqual(Score.compute(.init(licenseKind: .compatibleWithAppStore,
                                           releaseCount: 20,
                                           likeCount: 20_000,
                                           isArchived: false,
                                           numberOfDependencies: 2,
                                           lastActivityAt: Current.date().addingDays(-10),
                                           hasDocumentation: true)),
                       122)
    }
    
    func test_compute_package_versions() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, defaultBranch: "default", stars: 10_000).save(on: app.db).wait()
        try Version(package: pkg,
                    docArchives: [.init(name: "archive1", title: "Archive One")],
                    reference: .branch("default"),
                    swiftVersions: ["5"].asSwiftVersions).save(on: app.db).wait()
        try (0..<20).forEach {
            try Version(package: pkg, reference: .tag(.init($0, 0, 0)))
                .save(on: app.db).wait()
        }
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()
        // update versions
        try Analyze.updateLatestVersions(on: app.db, package: jpr).wait()
        let versions = try pkg.$versions.load(on: app.db)
            .map { pkg.versions }
            .wait()

        // MUT
        XCTAssertEqual(Score.compute(package: jpr, versions: versions), 97)
    }

}
