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

import XCTVapor


class VersionTests: AppTestCase {

    func test_save() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".asGithubUrl.url)
        let v = try Version(package: pkg)

        // MUT - save to create
        try v.save(on: app.db).wait()

        // validation
        XCTAssertEqual(v.$package.id, pkg.id)

        v.commit = "commit"
        v.latest = .defaultBranch
        v.packageName = "pname"
        v.publishedAt = Date(timeIntervalSince1970: 1)
        v.reference = .branch("branch")
        v.releaseNotes = "release notes"
        v.resolvedDependencies = [.init(packageName: "foo",
                                        repositoryURL: "http://foo") ]
        v.supportedPlatforms = [.ios("13"), .macos("10.15")]
        v.swiftVersions = ["4.0", "5.2"].asSwiftVersions
        v.url = pkg.versionUrl(for: v.reference)

        // MUT - save to update
        try v.save(on: app.db).wait()

        do {  // validation
            let v = try XCTUnwrap(Version.find(v.id, on: app.db).wait())
            XCTAssertEqual(v.commit, "commit")
            XCTAssertEqual(v.latest, .defaultBranch)
            XCTAssertEqual(v.packageName, "pname")
            XCTAssertEqual(v.publishedAt, Date(timeIntervalSince1970: 1))
            XCTAssertEqual(v.reference, .branch("branch"))
            XCTAssertEqual(v.releaseNotes, "release notes")
            XCTAssertEqual(v.resolvedDependencies?.map(\.packageName),
                           ["foo"])
            XCTAssertEqual(v.supportedPlatforms, [.ios("13"), .macos("10.15")])
            XCTAssertEqual(v.swiftVersions, ["4.0", "5.2"].asSwiftVersions)
            XCTAssertEqual(v.url, "https://github.com/foo/1/tree/branch")
        }
    }

    func test_save_not_null_constraints() async throws {
        do {  // commit unset
            let v = Version()
            v.commitDate = .distantPast
            v.reference = .branch("main")
            try await v.save(on: app.db)
            XCTFail("save must fail")
        } catch {
            // validation
            XCTAssertEqual(error.localizedDescription,
                           #"server: null value in column "commit" of relation "versions" violates not-null constraint (ExecConstraints)"#)
        }

        do {  // commitDate unset
            let v = Version()
            v.commit = ""
            v.reference = .branch("main")
            try await v.save(on: app.db)
            XCTFail("save must fail")
        } catch {
            // validation
            XCTAssertEqual(error.localizedDescription,
                           #"server: null value in column "commit_date" of relation "versions" violates not-null constraint (ExecConstraints)"#)
        }

        do {  // reference unset
            let v = Version()
            v.commit = ""
            v.commitDate = .distantPast
            try await v.save(on: app.db)
            XCTFail("save must fail")
        } catch {
            // validation
            XCTAssertEqual(error.localizedDescription,
                           #"server: null value in column "reference" of relation "versions" violates not-null constraint (ExecConstraints)"#)
        }
    }

    func test_empty_array_error() throws {
        // Test for
        // invalid field: swift_versions type: Array<SemVer> error: Unexpected data type: JSONB[]. Expected array.
        // Fix is .sql(.default("{}"))
        // setup

        let pkg = try savePackage(on: app.db, "1")
        let v = try Version(package: pkg)

        // MUT
        try v.save(on: app.db).wait()

        // validation
        _ = try XCTUnwrap(Version.find(v.id, on: app.db).wait())
    }

    func test_delete_cascade() throws {
        // delete package must delete version
        // setup

        let pkg = Package(id: UUID(), url: "1")
        let ver = try Version(id: UUID(), package: pkg)
        try pkg.save(on: app.db).wait()
        try ver.save(on: app.db).wait()

        XCTAssertEqual(try Package.query(on: app.db).count().wait(), 1)
        XCTAssertEqual(try Version.query(on: app.db).count().wait(), 1)

        // MUT
        try pkg.delete(on: app.db).wait()

        // version should be deleted
        XCTAssertEqual(try Package.query(on: app.db).count().wait(), 0)
        XCTAssertEqual(try Version.query(on: app.db).count().wait(), 0)
    }

    func test_isBranch() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".asGithubUrl.url)
        let v1 = try Version(package: pkg, reference: .branch("main"))
        let v2 = try Version(package: pkg, reference: .tag(1, 2, 3))

        // MUT & validate
        XCTAssertTrue(v1.isBranch)
        XCTAssertFalse(v2.isBranch)
    }

    func test_latestBranchVersion() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".asGithubUrl.url)
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
        XCTAssertEqual(latest?.id, vid)
    }

}
