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

import DependenciesTestSupport
import Testing


extension AllTests.ScoreTests {

    @Test(.dependency(\.date.now, .t0))
    func computeBreakdown() throws {
        #expect(Score.computeBreakdown(.init(licenseKind: .none,
                                             releaseCount: 0,
                                             likeCount: 0,
                                             isArchived: false,
                                             numberOfDependencies: nil,
                                             lastActivityAt: .t0.adding(days: -400),
                                             hasDocumentation: false,
                                             hasReadme: false,
                                             numberOfContributors: 0,
                                             hasTestTargets: false)).score == 20)
        #expect(Score.computeBreakdown(.init(licenseKind: .incompatibleWithAppStore,
                                             releaseCount: 0,
                                             likeCount: 0,
                                             isArchived: false,
                                             numberOfDependencies: nil,
                                             lastActivityAt: .t0.adding(days: -400),
                                             hasDocumentation: false,
                                             hasReadme: false,
                                             numberOfContributors: 0,
                                             hasTestTargets: false)).score == 23)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 0,
                                             likeCount: 0,
                                             isArchived: false,
                                             numberOfDependencies: nil,
                                             lastActivityAt: .t0.adding(days: -400),
                                             hasDocumentation: false,
                                             hasReadme: false,
                                             numberOfContributors: 0,
                                             hasTestTargets: false)).score == 30)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 10,
                                             likeCount: 0,
                                             isArchived: false,
                                             numberOfDependencies: nil,
                                             lastActivityAt: .t0.adding(days: -400),
                                             hasDocumentation: false,
                                             hasReadme: false,
                                             numberOfContributors: 0,
                                             hasTestTargets: false)).score == 40)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 10,
                                             likeCount: 50,
                                             isArchived: false,
                                             numberOfDependencies: nil,
                                             lastActivityAt: .t0.adding(days: -400),
                                             hasDocumentation: false,
                                             hasReadme: false,
                                             numberOfContributors: 0,
                                             hasTestTargets: false)).score == 50)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 10,
                                             likeCount: 50,
                                             isArchived: true,
                                             numberOfDependencies: nil,
                                             lastActivityAt: .t0.adding(days: -400),
                                             hasDocumentation: false,
                                             hasReadme: false,
                                             numberOfContributors: 0,
                                             hasTestTargets: false)).score == 30)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 20,
                                             likeCount: 20_000,
                                             isArchived: false,
                                             numberOfDependencies: nil,
                                             lastActivityAt: .t0.adding(days: -400),
                                             hasDocumentation: false,
                                             hasReadme: false,
                                             numberOfContributors: 0,
                                             hasTestTargets: false)).score == 87)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 20,
                                             likeCount: 20_000,
                                             isArchived: false,
                                             numberOfDependencies: 4,
                                             lastActivityAt: .t0.adding(days: -400),
                                             hasDocumentation: false,
                                             hasReadme: false,
                                             numberOfContributors: 0,
                                             hasTestTargets: false)).score == 89)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 20,
                                             likeCount: 20_000,
                                             isArchived: false,
                                             numberOfDependencies: 2,
                                             lastActivityAt: .t0.adding(days: -400),
                                             hasDocumentation: false,
                                             hasReadme: false,
                                             numberOfContributors: 0,
                                             hasTestTargets: false)).score == 92)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 20,
                                             likeCount: 20_000,
                                             isArchived: false,
                                             numberOfDependencies: 2,
                                             lastActivityAt: .t0.adding(days: -400),
                                             hasDocumentation: false,
                                             hasReadme: false,
                                             numberOfContributors: 0,
                                             hasTestTargets: false)).score == 92)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 20,
                                             likeCount: 20_000,
                                             isArchived: false,
                                             numberOfDependencies: 2,
                                             lastActivityAt: .t0.adding(days: -300),
                                             hasDocumentation: false,
                                             hasReadme: false,
                                             numberOfContributors: 0,
                                             hasTestTargets: false)).score == 97)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 20,
                                             likeCount: 20_000,
                                             isArchived: false,
                                             numberOfDependencies: 2,
                                             lastActivityAt: .t0.adding(days: -100),
                                             hasDocumentation: false,
                                             hasReadme: false,
                                             numberOfContributors: 0,
                                             hasTestTargets: false)).score == 102)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 20,
                                             likeCount: 20_000,
                                             isArchived: false,
                                             numberOfDependencies: 2,
                                             lastActivityAt: .t0.adding(days: -10),
                                             hasDocumentation: false,
                                             hasReadme: false,
                                             numberOfContributors: 0,
                                             hasTestTargets: false)).score == 107)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 20,
                                             likeCount: 20_000,
                                             isArchived: false,
                                             numberOfDependencies: 2,
                                             lastActivityAt: .t0.adding(days: -10),
                                             hasDocumentation: true,
                                             hasReadme: false,
                                             numberOfContributors: 0,
                                             hasTestTargets: false)).score == 122)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 20,
                                             likeCount: 20_000,
                                             isArchived: false,
                                             numberOfDependencies: 2,
                                             lastActivityAt: .t0.adding(days: -10),
                                             hasDocumentation: true,
                                             hasReadme: false,
                                             numberOfContributors: 5,
                                             hasTestTargets: false)).score == 127)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 20,
                                             likeCount: 20_000,
                                             isArchived: false,
                                             numberOfDependencies: 2,
                                             lastActivityAt: .t0.adding(days: -10),
                                             hasDocumentation: true,
                                             hasReadme: false,
                                             numberOfContributors: 20,
                                             hasTestTargets: false)).score == 132)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 20,
                                             likeCount: 20_000,
                                             isArchived: false,
                                             numberOfDependencies: 2,
                                             lastActivityAt: .t0.adding(days: -10),
                                             hasDocumentation: false,
                                             hasReadme: false,
                                             numberOfContributors: 0,
                                             hasTestTargets: false)).score == 107)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 20,
                                             likeCount: 20_000,
                                             isArchived: false,
                                             numberOfDependencies: 2,
                                             lastActivityAt: .t0.adding(days: -10),
                                             hasDocumentation: false,
                                             hasReadme: false,
                                             numberOfContributors: 0,
                                             hasTestTargets: true)).score == 112)
        #expect(Score.computeBreakdown(.init(licenseKind: .compatibleWithAppStore,
                                             releaseCount: 20,
                                             likeCount: 20_000,
                                             isArchived: false,
                                             numberOfDependencies: 2,
                                             lastActivityAt: .t0.adding(days: -10),
                                             hasDocumentation: false,
                                             hasReadme: true,
                                             numberOfContributors: 0,
                                             hasTestTargets: false)).score == 122)
    }

    @Test(.dependency(\.date.now, .now))
    func computeDetails() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1")
            try await Repository(package: pkg, defaultBranch: "default", stars: 10_000).save(on: app.db)
            try await Version(package: pkg,
                              docArchives: [.init(name: "archive1", title: "Archive One")],
                              reference: .branch("default"),
                              resolvedDependencies: [],
                              swiftVersions: ["5"].asSwiftVersions).save(on: app.db)
            for idx in (0..<20) {
                try await Version(package: pkg, reference: .tag(.init(idx, 0, 0))).save(on: app.db)
            }
            let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)
            // update versions
            let versions = try await Analyze.updateLatestVersions(on: app.db, package: jpr)

            // MUT
            let details = Score.computeDetails(repo: jpr.repository, versions: versions)

            do { // validate
                let details = try #require(details)
                #expect(details.scoreBreakdown == [
                    .archive: 20,
                    .dependencies: 5,
                    .documentation: 15,
                    .releases: 20,
                    .stars: 37,
                ])
                #expect(details.score == 97)
            }
        }
    }

    @Test(.dependency(\.date.now, .now))
    func computeDetails_unknown_resolvedDependencies() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1")
            try await Repository(package: pkg, defaultBranch: "default", stars: 10_000).save(on: app.db)
            try await Version(package: pkg,
                              docArchives: [.init(name: "archive1", title: "Archive One")],
                              reference: .branch("default"),
                              resolvedDependencies: nil,
                              swiftVersions: ["5"].asSwiftVersions).save(on: app.db)
            for idx in (0..<20) {
                try await Version(package: pkg, reference: .tag(.init(idx, 0, 0))).save(on: app.db)
            }
            let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)
            // update versions
            let versions = try await Analyze.updateLatestVersions(on: app.db, package: jpr)

            // MUT
            let details = Score.computeDetails(repo: jpr.repository, versions: versions)

            do { // validate
                let details = try #require(details)
                #expect(details.scoreBreakdown == [
                    .archive: 20,
                    // no .dependencies category
                    .documentation: 15,
                    .releases: 20,
                    .stars: 37,
                ])
                #expect(details.score == 92)
            }
        }
    }

}
