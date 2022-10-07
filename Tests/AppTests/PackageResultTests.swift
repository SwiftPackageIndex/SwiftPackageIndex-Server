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


class PackageResultTests: AppTestCase {
    typealias PackageResult = PackageController.PackageResult

    func test_joined5() async throws {
        do {
            let pkg = try savePackage(on: app.db, "1".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 forks: 42,
                                 license: .mit,
                                 name: "bar",
                                 owner: "foo",
                                 stars: 17,
                                 summary: "summary").save(on: app.db)
            do {
                try await App.Version(package: pkg,
                                      latest: .defaultBranch,
                                      reference: .branch("main")
                ).save(on: app.db)
            }
            do {
                try await App.Version(package: pkg,
                                      latest: .release,
                                      reference: .tag(1, 2, 3)
                ).save(on: app.db)
            }
            do {
                try await App.Version(package: pkg,
                                      latest: .preRelease,
                                      reference: .tag(2, 0, 0, "b1")
                ).save(on: app.db)
            }
        }

        // MUT
        let res = try await PackageController.PackageResult
            .query(on: app.db, owner: "foo", repository: "bar")

        // validate
        XCTAssertEqual(res.model.url, "1")
        XCTAssertEqual(res.repository.name, "bar")
        XCTAssertEqual(res.defaultBranchVersion.reference, .branch("main"))
        XCTAssertEqual(res.releaseVersion?.reference, .tag(1, 2, 3))
        XCTAssertEqual(res.preReleaseVersion?.reference, .tag(2, 0, 0, "b1"))
    }

    func test_joined5_no_preRelease() async throws {
        do {
            // FIXME: add unrelated package and version to test right/left join correctness
            let pkg = try savePackage(on: app.db, "1".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 forks: 42,
                                 license: .mit,
                                 name: "bar",
                                 owner: "foo",
                                 stars: 17,
                                 summary: "summary").save(on: app.db)
            do {
                try await App.Version(package: pkg,
                                      latest: .defaultBranch,
                                      reference: .branch("main")
                ).save(on: app.db)
            }
            do {
                try await App.Version(package: pkg,
                                      latest: .release,
                                      reference: .tag(1, 2, 3)
                ).save(on: app.db)
            }
        }

        // MUT
        let res = try await PackageController.PackageResult
            .query(on: app.db, owner: "foo", repository: "bar")

        // validate
        XCTAssertEqual(res.model.url, "1")
        XCTAssertEqual(res.repository.name, "bar")
        XCTAssertEqual(res.defaultBranchVersion.reference, .branch("main"))
        XCTAssertEqual(res.releaseVersion?.reference, .tag(1, 2, 3))
    }

    func test_joined5_defaultBranch_only() async throws {
        do {
            // FIXME: add unrelated package and version to test right/left join correctness
            let pkg = try savePackage(on: app.db, "1".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 forks: 42,
                                 license: .mit,
                                 name: "bar",
                                 owner: "foo",
                                 stars: 17,
                                 summary: "summary").save(on: app.db)
            do {
                try await App.Version(package: pkg,
                                      latest: .defaultBranch,
                                      reference: .branch("main")
                ).save(on: app.db)
            }
        }

        // MUT
        let res = try await PackageController.PackageResult
            .query(on: app.db, owner: "foo", repository: "bar")

        // validate
        XCTAssertEqual(res.model.url, "1")
        XCTAssertEqual(res.repository.name, "bar")
        XCTAssertEqual(res.defaultBranchVersion.reference, .branch("main"))
    }

    func test_query_owner_repository() async throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try await Repository(package: pkg,
                             defaultBranch: "main",
                             forks: 42,
                             license: .mit,
                             name: "bar",
                             owner: "foo",
                             stars: 17,
                             summary: "summary").save(on: app.db)
        let version = try App.Version(package: pkg,
                                      latest: .defaultBranch,
                                      packageName: "test package",
                                      reference: .branch("main"))
        try await version.save(on: app.db)

        // MUT
        let res = try await PackageResult.query(on: app.db, owner: "foo", repository: "bar")

        // validate
        XCTAssertEqual(res.package.id, pkg.id)
        XCTAssertEqual(res.repository.name, "bar")
    }

    func test_query_owner_repository_case_insensitivity() async throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try await Repository(package: pkg,
                             defaultBranch: "main",
                             forks: 42,
                             license: .mit,
                             name: "bar",
                             owner: "foo",
                             stars: 17,
                             summary: "summary").save(on: app.db)
        let version = try App.Version(package: pkg,
                                      latest: .defaultBranch,
                                      packageName: "test package",
                                      reference: .branch("main"))
        try await version.save(on: app.db)

        // MUT
        let res = try await PackageResult.query(on: app.db, owner: "Foo", repository: "bar")

        // validate
        XCTAssertEqual(res.package.id, pkg.id)
    }

    func test_activity() async throws {
        // setup
        let m: TimeInterval = 60
        let H = 60*m
        let d = 24*H
        let pkg = try savePackage(on: app.db, "https://github.com/Alamofire/Alamofire")
        try await Repository(package: pkg,
                             lastIssueClosedAt: Date(timeIntervalSinceNow: -5*d),
                             lastPullRequestClosedAt: Date(timeIntervalSinceNow: -6*d),
                             name: "bar",
                             openIssues: 27,
                             openPullRequests: 1,
                             owner: "foo").create(on: app.db)
        try await Version(package: pkg, latest: .defaultBranch).save(on: app.db)
        let pr = try await PackageResult.query(on: app.db, owner: "foo", repository: "bar")
        
        
        // MUT
        let res = pr.activity()
        
        // validate
        XCTAssertEqual(res,
                       .init(openIssuesCount: 27,
                             openIssues: .init(label: "27 open issues",
                                               url: "https://github.com/Alamofire/Alamofire/issues"),
                             openPullRequests: .init(label: "1 open pull request",
                                                     url: "https://github.com/Alamofire/Alamofire/pulls"),
                             lastIssueClosedAt: "5 days ago",
                             lastPullRequestClosedAt: "6 days ago"))
    }

    func test_documentationTarget_withExternalUrl() async throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try await Repository(package: pkg,
                             name: "bar",
                             owner: "foo").save(on: app.db)
        let version = try App.Version(package: pkg,
                                      commit: "0123456789",
                                      commitDate: Date(timeIntervalSince1970: 0),
                                      docArchives: [
                                        // Inserting an archive here to test that the external URL overrides any generated docs.
                                        .init(name: "archive1", title: "Archive One")
                                      ],
                                      latest: .defaultBranch,
                                      packageName: "test",
                                      reference: .branch("main"),
                                      spiManifest: .init(yml: """
                                        version: 1
                                        external_links:
                                          documentation: https://example.com/package/documentation/
                                        """))
        try await version.save(on: app.db)

        // MUT
        let res = try await PackageResult.query(on: app.db, owner: "foo", repository: "bar")

        // validate
        XCTAssertEqual(res.documentationTarget, .external(url: "https://example.com/package/documentation/"))
    }

    func test_documentationTarget_withDocArchive_defaultBranch() async throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try await Repository(package: pkg,
                             name: "bar",
                             owner: "foo").save(on: app.db)
        try await App.Version(package: pkg,
                              commit: "0123456789",
                              commitDate: Date(timeIntervalSince1970: 0),
                              docArchives: [
                                .init(name: "archive1", title: "Archive One")
                              ],
                              latest: .defaultBranch,
                              packageName: "test",
                              reference: .branch("main")).save(on: app.db)

        // MUT
        let res = try await PackageResult.query(on: app.db, owner: "foo", repository: "bar")

        // validate
        XCTAssertEqual(res.documentationTarget, .internal(url: "", reference: "main", archive: "archive1"))
    }

    func test_documentationTarget_withDocArchive_stableBranch() async throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try await Repository(package: pkg,
                             name: "bar",
                             owner: "foo").save(on: app.db)
        try await App.Version(package: pkg,
                              commit: "0000000000",
                              commitDate: Date(timeIntervalSince1970: 0),
                              docArchives: [
                                .init(name: "archive1", title: "Archive One")
                              ],
                              latest: .defaultBranch,
                              packageName: "test",
                              reference: .branch("main")).save(on: app.db)
        try await App.Version(package: pkg,
                              commit: "11111111111",
                              commitDate: Date(timeIntervalSince1970: 0),
                              docArchives: [
                                .init(name: "archive2", title: "Archive Two")
                              ],
                              latest: .release,
                              packageName: "test",
                              reference: .tag(1, 0, 0)).save(on: app.db)

        // MUT
        let res = try await PackageResult.query(on: app.db, owner: "foo", repository: "bar")

        // validate
        XCTAssertEqual(res.documentationTarget, .internal(url: "", reference: "1.0.0", archive: "archive2"))
    }
}
