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

import SemanticVersion
import Testing


extension AllTests.PackageResultTests {
    typealias PackageResult = PackageController.PackageResult

    @Test func joined5() async throws {
        try await withApp { app in
            let pkg = try await savePackage(on: app.db, "1".url)
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
            #expect(res.model.url == "1")
            #expect(res.repository.name == "bar")
            #expect(res.defaultBranchVersion.reference == .branch("main"))
            #expect(res.releaseVersion?.reference == .tag(1, 2, 3))
            #expect(res.preReleaseVersion?.reference == .tag(2, 0, 0, "b1"))
        }
    }

    @Test func joined5_no_preRelease() async throws {
        try await withApp { app in
            do {
                let pkg = try await savePackage(on: app.db, "1".url)
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
                let pkg = try await savePackage(on: app.db, "2".url)
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
            #expect(res.model.url == "1")
            #expect(res.repository.name == "bar1")
            #expect(res.defaultBranchVersion.reference == .branch("main"))
            #expect(res.releaseVersion?.reference == .tag(1, 2, 3))
        }
    }

    @Test func joined5_defaultBranch_only() async throws {
        try await withApp { app in
            do {
                let pkg = try await savePackage(on: app.db, "1".url)
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
                let pkg = try await savePackage(on: app.db, "2".url)
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
            #expect(res.model.url == "1")
            #expect(res.repository.name == "bar1")
            #expect(res.defaultBranchVersion.reference == .branch("main"))
        }
    }

    @Test func query_owner_repository() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1".url)
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
            #expect(res.package.id == pkg.id)
            #expect(res.repository.name == "bar")
        }
    }

    @Test func query_owner_repository_case_insensitivity() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1".url)
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
            #expect(res.package.id == pkg.id)
        }
    }

    @Test func activity() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "https://github.com/Alamofire/Alamofire")
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
            #expect(res == .init(openIssuesCount: 27,
                                 openIssuesURL: "https://github.com/Alamofire/Alamofire/issues",
                                 openPullRequestsCount: 1,
                                 openPullRequestsURL: "https://github.com/Alamofire/Alamofire/pulls",
                                 lastIssueClosedAt: .t0,
                                 lastPullRequestClosedAt: .t1))
        }
    }

    @Test func canonicalDocumentationTarget() async throws {
        try await withApp { app in
            // setup
            do {
                // first package has docs
                let pkg = try await savePackage(on: app.db, "1".url)
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
                let pkg = try await savePackage(on: app.db, "2".url)
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
                #expect(res.canonicalDocumentationTarget() == .internal(docVersion: .reference("main"), archive: "foo"))
            }

            do {
                // MUT
                let res = try await PackageController.PackageResult
                    .query(on: app.db, owner: "foo", repository: "bar2")

                // validate
                #expect(res.canonicalDocumentationTarget() == nil)
            }
        }
    }
    
}
