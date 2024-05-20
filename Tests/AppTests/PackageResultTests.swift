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

import XCTest

@testable import App

import SemanticVersion


class PackageResultTests: AppTestCase {
    typealias PackageResult = PackageController.PackageResult

    func test_joined5() async throws {
        let pkg = try savePackage(on: app.db, "1".url)
        try await Repository(package: pkg,
                             defaultBranch: "main",
                             forks: 42,
                             license: .mit,
                             name: "bar",
                             owner: "foo",
                             stars: 17,
                             summary: "summary").save(on: app.db)
        try await App.Version(package: pkg,
                              latest: .defaultBranch,
                              reference: .branch("main")).save(on: app.db)
        try await App.Version(package: pkg,
                              latest: .release,
                              reference: .tag(1, 2, 3)).save(on: app.db)
        try await App.Version(package: pkg,
                              latest: .preRelease,
                              reference: .tag(2, 0, 0, "b1")).save(on: app.db)

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
            let pkg = try savePackage(on: app.db, "1".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 forks: 42,
                                 license: .mit,
                                 name: "bar1",
                                 owner: "foo",
                                 stars: 17,
                                 summary: "summary").save(on: app.db)
            try await App.Version(package: pkg,
                                  latest: .defaultBranch,
                                  reference: .branch("main")).save(on: app.db)
            try await App.Version(package: pkg,
                                  latest: .release,
                                  reference: .tag(1, 2, 3)).save(on: app.db)
        }
        do {
            // unrelated package to test join behaviour
            let pkg = try savePackage(on: app.db, "2".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 forks: 42,
                                 license: .mit,
                                 name: "bar2",
                                 owner: "foo",
                                 stars: 17,
                                 summary: "summary").save(on: app.db)
            try await App.Version(package: pkg,
                                  latest: .defaultBranch,
                                  reference: .branch("main")).save(on: app.db)
            try await App.Version(package: pkg,
                                  latest: .release,
                                  reference: .tag(1, 2, 3)).save(on: app.db)
        }

        // MUT
        let res = try await PackageController.PackageResult
            .query(on: app.db, owner: "foo", repository: "bar1")

        // validate
        XCTAssertEqual(res.model.url, "1")
        XCTAssertEqual(res.repository.name, "bar1")
        XCTAssertEqual(res.defaultBranchVersion.reference, .branch("main"))
        XCTAssertEqual(res.releaseVersion?.reference, .tag(1, 2, 3))
    }

    func test_joined5_defaultBranch_only() async throws {
        do {
            let pkg = try savePackage(on: app.db, "1".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 forks: 42,
                                 license: .mit,
                                 name: "bar1",
                                 owner: "foo",
                                 stars: 17,
                                 summary: "summary").save(on: app.db)
            try await App.Version(package: pkg,
                                  latest: .defaultBranch,
                                  reference: .branch("main")).save(on: app.db)
        }
        do {
            // unrelated package to test join behaviour
            let pkg = try savePackage(on: app.db, "2".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 forks: 42,
                                 license: .mit,
                                 name: "bar2",
                                 owner: "foo",
                                 stars: 17,
                                 summary: "summary").save(on: app.db)
            try await App.Version(package: pkg,
                                  latest: .defaultBranch,
                                  reference: .branch("main")).save(on: app.db)
            try await App.Version(package: pkg,
                                  latest: .release,
                                  reference: .tag(1, 2, 3)).save(on: app.db)
        }

        // MUT
        let res = try await PackageController.PackageResult
            .query(on: app.db, owner: "foo", repository: "bar1")

        // validate
        XCTAssertEqual(res.model.url, "1")
        XCTAssertEqual(res.repository.name, "bar1")
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
        let pkg = try savePackage(on: app.db, "https://github.com/Alamofire/Alamofire")
        try await Repository(package: pkg,
                             lastIssueClosedAt: .t0,
                             lastPullRequestClosedAt: .t1,
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
                             openIssuesURL: "https://github.com/Alamofire/Alamofire/issues",
                             openPullRequestsCount: 1,
                             openPullRequestsURL: "https://github.com/Alamofire/Alamofire/pulls",
                             lastIssueClosedAt: .t0,
                             lastPullRequestClosedAt: .t1))
    }

    func test_canonicalDocumentationTarget() async throws {
        // setup
        do {
            // first package has docs
            let pkg = try savePackage(on: app.db, "1".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 forks: 42,
                                 license: .mit,
                                 name: "bar1",
                                 owner: "foo",
                                 stars: 17,
                                 summary: "summary").save(on: app.db)
            do {
                try await App.Version(package: pkg,
                                      docArchives: [.init(name: "foo", title: "Foo")],
                                      latest: .defaultBranch,
                                      reference: .branch("main")).save(on: app.db)
            }
            do {
                try await App.Version(package: pkg,
                                      latest: .release,
                                      reference: .tag(1, 2, 3)).save(on: app.db)
            }
            do {
                try await App.Version(package: pkg,
                                      latest: .preRelease,
                                      reference: .tag(2, 0, 0, "b1")).save(on: app.db)
            }
        }
        do {
            // second package doesn't have docs
            let pkg = try savePackage(on: app.db, "2".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 forks: 42,
                                 license: .mit,
                                 name: "bar2",
                                 owner: "foo",
                                 stars: 17,
                                 summary: "summary").save(on: app.db)
            try await App.Version(package: pkg,
                                  latest: .defaultBranch,
                                  reference: .branch("main")).save(on: app.db)
        }

        do {
            // MUT
            let res = try await PackageController.PackageResult
                .query(on: app.db, owner: "foo", repository: "bar1")

            // validate
            XCTAssertEqual(res.canonicalDocumentationTarget(), .internal(docVersion: .reference("main"), archive: "foo"))
        }

        do {
            // MUT
            let res = try await PackageController.PackageResult
                .query(on: app.db, owner: "foo", repository: "bar2")

            // validate
            XCTAssertEqual(res.canonicalDocumentationTarget(), nil)
        }
    }

    func test_currentDocumentationTarget() async throws {
        do {
            // Test package with branch docs and stable version docs
            let pkg = try savePackage(on: app.db, "1".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 forks: 42,
                                 license: .mit,
                                 name: "bar1",
                                 owner: "foo",
                                 stars: 17,
                                 summary: "summary").save(on: app.db)
            try await App.Version(package: pkg,
                                  docArchives: [.init(name: "archive1", title: "Archive 1")],
                                  latest: .defaultBranch,
                                  reference: .branch("main")).save(on: app.db)
            try await App.Version(package: pkg,
                                  // Note the name change on the default branch. The current should point to this archive.
                                  docArchives: [.init(name: "archive2", title: "Archive 2")],
                                  latest: .release,
                                  reference: .tag(1, 2, 3)).save(on: app.db)
        }

        do {
            // Test package with only branch docs hosted externally.
            let pkg = try savePackage(on: app.db, "2".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 forks: 42,
                                 license: .mit,
                                 name: "bar2",
                                 owner: "foo",
                                 stars: 17,
                                 summary: "summary").save(on: app.db)
            try await App.Version(package: pkg,
                                  latest: .defaultBranch,
                                  reference: .branch("main"),
                                  spiManifest: .init(externalLinks: .init(documentation: "https://example.com"))).save(on: app.db)
        }

        do {
            // Test package with no documentation
            let pkg = try savePackage(on: app.db, "3".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 forks: 42,
                                 license: .mit,
                                 name: "bar3",
                                 owner: "foo",
                                 stars: 17,
                                 summary: "summary").save(on: app.db)
            try await App.Version(package: pkg,
                                  latest: .defaultBranch,
                                  reference: .branch("main")).save(on: app.db)
        }

        do {
            // Testing for internally hosted documentation pointing at the "current".
            let res = try await PackageController.PackageResult.query(on: app.db, owner: "foo", repository: "bar1")
            let currentTarget = try XCTUnwrap(res.currentDocumentationTarget())

            // Validaton
            XCTAssertEqual(currentTarget, .internal(docVersion: .current(referencing: nil), archive: "archive2"))
        }

        do {
            // Testing for `.external` case pass-through.
            let res = try await PackageController.PackageResult.query(on: app.db, owner: "foo", repository: "bar2")
            let currentTarget = try XCTUnwrap(res.currentDocumentationTarget())

            // Validaton
            XCTAssertEqual(currentTarget, .external(url: "https://example.com"))
        }

        do {
            // Testing for "no documentation" pass-through.
            let res = try await PackageController.PackageResult.query(on: app.db, owner: "foo", repository: "bar3")

            // Validaton
            XCTAssertNil(res.currentDocumentationTarget())
        }
    }

}
