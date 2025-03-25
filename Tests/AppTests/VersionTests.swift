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

import Foundation

@testable import App

import PostgresKit
import Testing


extension AllTests.VersionTests {

    @Test func save() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1".asGithubUrl.url)
            let v = try Version(package: pkg)

            // MUT - save to create
            try await v.save(on: app.db)

            // validation
            #expect(v.$package.id == pkg.id)

            v.commit = "commit"
            v.latest = .defaultBranch
            v.packageName = "pname"
            v.productDependencies = [.init(identity: "foo", name: "Foo", url: "https://github.com/foo/Foo.git", dependencies: [])]
            v.publishedAt = Date(timeIntervalSince1970: 1)
            v.reference = .branch("branch")
            v.releaseNotes = "release notes"
            v.resolvedDependencies = [.init(packageName: "foo",
                                            repositoryURL: "http://foo") ]
            v.supportedPlatforms = [.ios("13"), .macos("10.15")]
            v.swiftVersions = ["4.0", "5.2"].asSwiftVersions
            v.url = pkg.versionUrl(for: v.reference)

            // MUT - save to update
            try await v.save(on: app.db)

            do {  // validation
                let v = try #require(try await Version.find(v.id, on: app.db))
                #expect(v.commit == "commit")
                #expect(v.latest == .defaultBranch)
                #expect(v.packageName == "pname")
                #expect(v.productDependencies == [.init(identity: "foo", name: "Foo", url: "https://github.com/foo/Foo.git", dependencies: [])])
                #expect(v.publishedAt == Date(timeIntervalSince1970: 1))
                #expect(v.reference == .branch("branch"))
                #expect(v.releaseNotes == "release notes")
                #expect(v.resolvedDependencies?.map(\.packageName) == ["foo"])
                #expect(v.supportedPlatforms == [.ios("13"), .macos("10.15")])
                #expect(v.swiftVersions == ["4.0", "5.2"].asSwiftVersions)
                #expect(v.url == "https://github.com/foo/1/tree/branch")
            }
        }
    }

    @Test func save_not_null_constraints() async throws {
        try await withApp { app in
            do {  // commit unset
                let v = Version()
                v.commitDate = .distantPast
                v.reference = .branch("main")
                try await v.save(on: app.db)
                Issue.record("save must fail")
            } catch {
                // validation
                #expect(error.serverMessage == #"null value in column "commit" of relation "versions" violates not-null constraint"#)
            }

            do {  // commitDate unset
                let v = Version()
                v.commit = ""
                v.reference = .branch("main")
                try await v.save(on: app.db)
                Issue.record("save must fail")
            } catch {
                // validation
                #expect(error.serverMessage == #"null value in column "commit_date" of relation "versions" violates not-null constraint"#)
            }

            do {  // reference unset
                let v = Version()
                v.commit = ""
                v.commitDate = .distantPast
                try await v.save(on: app.db)
                Issue.record("save must fail")
            } catch {
                // validation
                #expect(error.serverMessage == #"null value in column "reference" of relation "versions" violates not-null constraint"#)
            }
        }
    }

    @Test func empty_array_error() async throws {
        // Test for
        // invalid field: swift_versions type: Array<SemVer> error: Unexpected data type: JSONB[]. Expected array.
        // Fix is .sql(.default("{}"))
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1")
            let v = try Version(package: pkg)

            // MUT
            try await v.save(on: app.db)

            // validation
            _ = try #require(try await Version.find(v.id, on: app.db))
        }
    }

    @Test func delete_cascade() async throws {
        // delete package must delete version
        try await withApp { app in
            // setup
            let pkg = Package(id: UUID(), url: "1")
            let ver = try Version(id: UUID(), package: pkg)
            try await pkg.save(on: app.db)
            try await ver.save(on: app.db)

            #expect(try await Package.query(on: app.db).count() == 1)
            #expect(try await Version.query(on: app.db).count() == 1)

            // MUT
            try await pkg.delete(on: app.db)

            // version should be deleted
            #expect(try await Package.query(on: app.db).count() == 0)
            #expect(try await Version.query(on: app.db).count() == 0)
        }
    }

    @Test func isBranch() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1".asGithubUrl.url)
            let v1 = try Version(package: pkg, reference: .branch("main"))
            let v2 = try Version(package: pkg, reference: .tag(1, 2, 3))

            // MUT & validate
            #expect(v1.isBranch)
            #expect(!v2.isBranch)
        }
    }

    @Test func latestBranchVersion() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1".asGithubUrl.url)
            let vid = UUID()
            let v1 = try Version(id: UUID(),
                                 package: pkg,
                                 commitDate: .t0,
                                 reference: .branch("main"))
            let v2 = try Version(id: UUID(),
                                 package: pkg,
                                 commitDate: .t1,
                                 reference: .branch("main"))
            let v3 = try Version(id: vid,
                                 package: pkg,
                                 commitDate: .t2,
                                 reference: .branch("main"))
            let v4 = try Version(id: UUID(), package: pkg, reference: .tag(1, 2, 3))
            let v5 = try Version(id: UUID(), package: pkg, reference: .branch("main"))
            
            // MUT
            let latest = [v1, v2, v3, v4, v5].shuffled().latestBranchVersion
            
            // validate
            #expect(latest?.id == vid)
        }
    }

    @Test func defaults() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1".asGithubUrl.url)
            let v = try Version(package: pkg)

            // MUT
            try await v.save(on: app.db)

            do { // validate
                let v = try #require(try await Version.find(v.id, on: app.db))
                #expect(v.resolvedDependencies == nil)
                #expect(v.productDependencies == nil)
            }
        }
    }

}


private extension PSQLError {
    var serverMessage: String? { serverInfo?[.message] }
}


private extension Error {
    var serverMessage: String? { (self as? PSQLError)?.serverMessage }
}
