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


class ScoreTests: AppTestCase {

    func test_computeBreakdown() throws {
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .none,
                                                    releaseCount: 0,
                                                    likeCount: 0,
                                                    isArchived: false,
                                                    numberOfDependencies: nil,
                                                    lastActivityAt: Current.date().adding(days: -400),
                                                    hasDocumentation: false,
                                                    hasReadme: false,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: false)).score,
                       20)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .incompatibleWithAppStore,
                                                    releaseCount: 0,
                                                    likeCount: 0,
                                                    isArchived: false,
                                                    numberOfDependencies: nil,
                                                    lastActivityAt: Current.date().adding(days: -400),
                                                    hasDocumentation: false,
                                                    hasReadme: false,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: false)).score,
                       23)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 0,
                                                    likeCount: 0,
                                                    isArchived: false,
                                                    numberOfDependencies: nil,
                                                    lastActivityAt: Current.date().adding(days: -400),
                                                    hasDocumentation: false,
                                                    hasReadme: false,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: false)).score,
                       30)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 10,
                                                    likeCount: 0,
                                                    isArchived: false,
                                                    numberOfDependencies: nil,
                                                    lastActivityAt: Current.date().adding(days: -400),
                                                    hasDocumentation: false,
                                                    hasReadme: false,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: false)).score,
                       40)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 10,
                                                    likeCount: 50,
                                                    isArchived: false,
                                                    numberOfDependencies: nil,
                                                    lastActivityAt: Current.date().adding(days: -400),
                                                    hasDocumentation: false,
                                                    hasReadme: false,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: false)).score,
                       50)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 10,
                                                    likeCount: 50,
                                                    isArchived: true,
                                                    numberOfDependencies: nil,
                                                    lastActivityAt: Current.date().adding(days: -400),
                                                    hasDocumentation: false,
                                                    hasReadme: false,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: false)).score,
                       30)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 20,
                                                    likeCount: 20_000,
                                                    isArchived: false,
                                                    numberOfDependencies: nil,
                                                    lastActivityAt: Current.date().adding(days: -400),
                                                    hasDocumentation: false,
                                                    hasReadme: false,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: false)).score,
                       87)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 20,
                                                    likeCount: 20_000,
                                                    isArchived: false,
                                                    numberOfDependencies: 4,
                                                    lastActivityAt: Current.date().adding(days: -400),
                                                    hasDocumentation: false,
                                                    hasReadme: false,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: false)).score,
                       89)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 20,
                                                    likeCount: 20_000,
                                                    isArchived: false,
                                                    numberOfDependencies: 2,
                                                    lastActivityAt: Current.date().adding(days: -400),
                                                    hasDocumentation: false,
                                                    hasReadme: false,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: false)).score,
                       92)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 20,
                                                    likeCount: 20_000,
                                                    isArchived: false,
                                                    numberOfDependencies: 2,
                                                    lastActivityAt: Current.date().adding(days: -400),
                                                    hasDocumentation: false,
                                                    hasReadme: false,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: false)).score,
                       92)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 20,
                                                    likeCount: 20_000,
                                                    isArchived: false,
                                                    numberOfDependencies: 2,
                                                    lastActivityAt: Current.date().adding(days: -300),
                                                    hasDocumentation: false,
                                                    hasReadme: false,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: false)).score,
                       97)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 20,
                                                    likeCount: 20_000,
                                                    isArchived: false,
                                                    numberOfDependencies: 2,
                                                    lastActivityAt: Current.date().adding(days: -100),
                                                    hasDocumentation: false,
                                                    hasReadme: false,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: false)).score,
                       102)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 20,
                                                    likeCount: 20_000,
                                                    isArchived: false,
                                                    numberOfDependencies: 2,
                                                    lastActivityAt: Current.date().adding(days: -10),
                                                    hasDocumentation: false,
                                                    hasReadme: false,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: false)).score,
                       107)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 20,
                                                    likeCount: 20_000,
                                                    isArchived: false,
                                                    numberOfDependencies: 2,
                                                    lastActivityAt: Current.date().adding(days: -10),
                                                    hasDocumentation: true,
                                                    hasReadme: false,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: false)).score,
                       122)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 20,
                                                    likeCount: 20_000,
                                                    isArchived: false,
                                                    numberOfDependencies: 2,
                                                    lastActivityAt: Current.date().adding(days: -10),
                                                    hasDocumentation: true,
                                                    hasReadme: false,
                                                    numberOfContributors: 5,
                                                    hasTestTargets: false)).score,
                       127)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 20,
                                                    likeCount: 20_000,
                                                    isArchived: false,
                                                    numberOfDependencies: 2,
                                                    lastActivityAt: Current.date().adding(days: -10),
                                                    hasDocumentation: true,
                                                    hasReadme: false,
                                                    numberOfContributors: 20,
                                                    hasTestTargets: false)).score,
                       132)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 20,
                                                    likeCount: 20_000,
                                                    isArchived: false,
                                                    numberOfDependencies: 2,
                                                    lastActivityAt: Current.date().adding(days: -10),
                                                    hasDocumentation: false,
                                                    hasReadme: false,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: false)).score,
                       107)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 20,
                                                    likeCount: 20_000,
                                                    isArchived: false,
                                                    numberOfDependencies: 2,
                                                    lastActivityAt: Current.date().adding(days: -10),
                                                    hasDocumentation: false,
                                                    hasReadme: false,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: true)).score,
                       112)
        XCTAssertEqual(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                                    releaseCount: 20,
                                                    likeCount: 20_000,
                                                    isArchived: false,
                                                    numberOfDependencies: 2,
                                                    lastActivityAt: Current.date().adding(days: -10),
                                                    hasDocumentation: false,
                                                    hasReadme: true,
                                                    numberOfContributors: 0,
                                                    hasTestTargets: false)).score,
                       122)
    }

    func test_computeDetails() async throws {
        // setup
        let pkg = try await savePackageAsync(on: app.db, "1")
        try await Repository(package: pkg, defaultBranch: "default", stars: 10_000).save(on: app.db)
        try await Version(package: pkg,
                          docArchives: [.init(name: "archive1", title: "Archive One")],
                          reference: .branch("default"),
                          swiftVersions: ["5"].asSwiftVersions).save(on: app.db)
        try (0..<20).forEach {
            try Version(package: pkg, reference: .tag(.init($0, 0, 0)))
                .save(on: app.db).wait()
        }
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)
        // update versions
        let versions = try await Analyze.updateLatestVersions(on: app.db, package: jpr)

        // MUT
        let details = Score.computeDetails(repo: jpr.repository, versions: versions)

        do { // validate
            let details = try XCTUnwrap(details)
            XCTAssertEqual(details.scoreBreakdown, [
                .archive: 20,
                .dependencies: 5,
                .documentation: 15,
                .releases: 20,
                .stars: 37,
            ])
            XCTAssertEqual(details.score, 97)
        }
    }
}
