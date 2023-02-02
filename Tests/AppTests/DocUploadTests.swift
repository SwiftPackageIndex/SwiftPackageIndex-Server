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

import PostgresKit
import XCTVapor


final class DocUploadTests: AppTestCase {

    func test_attach() async throws {
        // setup
        let pkg = try await savePackageAsync(on: app.db, "1")
        let versionId = UUID()
        let buildId = UUID()
        let docUploadId = UUID()
        let v = try Version(id: versionId, package: pkg)
        try await v.save(on: app.db)
        let b = try Build(id: buildId, version: v, platform: .linux, status: .ok, swiftVersion: .v5_7)
        try await b.save(on: app.db)
        let d = try DocUpload(id: docUploadId,
                              error: "error",
                              fileCount: 1,
                              logUrl: "logUrl",
                              mbSize: 2,
                              status: .ok)

        // MUT
        try await d.attach(to: b, on: app.db)

        do { // validate
            let d = try await XCTUnwrapAsync(try await DocUpload.find(docUploadId, on: app.db))
            XCTAssertEqual(d.error, "error")
            XCTAssertEqual(d.fileCount, 1)
            XCTAssertEqual(d.logUrl, "logUrl")
            XCTAssertEqual(d.mbSize, 2)
            XCTAssertEqual(d.status, .ok)
            // check relationship
            let b = try await XCTUnwrapAsync(try await Build.find(buildId, on: app.db))
            try await b.$docUpload.load(on: app.db)
            XCTAssertEqual(b.docUpload?.id, docUploadId)
        }
    }

    func test_detachAndDelete() async throws {
        // Ensure deleting doc_uploads doesn't cascade into builds
        // setup
        let pkg = try await savePackageAsync(on: app.db, "1")
        let v = try Version(id: UUID(), package: pkg)
        try await v.save(on: app.db)
        let buildId = UUID()
        let b = try Build(id: buildId, version: v, platform: .linux, status: .ok, swiftVersion: .v5_7)
        try await b.save(on: app.db)
        let docUploadId = UUID()
        try await DocUpload(id: docUploadId, status: .ok)
            .attach(to: b, on: app.db)
        try await XCTAssertEqualAsync(try await Version.query(on: app.db).count(), 1)
        try await XCTAssertEqualAsync(try await Build.query(on: app.db).count(), 1)
        try await XCTAssertEqualAsync(try await DocUpload.query(on: app.db).count(), 1)

        // MUT
        try await DocUpload.find(docUploadId, on: app.db)?
            .detachAndDelete(on: app.db)

        // validate
        try await XCTAssertEqualAsync(try await Version.query(on: app.db).count(), 1)
        try await XCTAssertEqualAsync(try await Build.query(on: app.db).count(), 1)
        try await XCTAssertEqualAsync(try await DocUpload.query(on: app.db).count(), 0)
        do {  // Ensure b.doc_upload_id is reset
            let b = try await XCTUnwrapAsync(try await Build.find(buildId, on: app.db))
            XCTAssertNil(b.docUpload)
            XCTAssertNil(b.$docUpload.id)
        }
    }

    func test_delete_cascade_build() async throws {
        // setup
        let pkg = try await savePackageAsync(on: app.db, "1")
        let buildId = UUID()
        let v = try Version(id: UUID(), package: pkg)
        try await v.save(on: app.db)
        let b = try Build(id: buildId, version: v, platform: .linux, status: .ok, swiftVersion: .v5_7)
        try await b.save(on: app.db)
        try await DocUpload(id: UUID(), status: .ok)
            .attach(to: b, on: app.db)

        try await XCTAssertEqualAsync(try await Version.query(on: app.db).count(), 1)
        try await XCTAssertEqualAsync(try await Build.query(on: app.db).count(), 1)
        try await XCTAssertEqualAsync(try await DocUpload.query(on: app.db).count(), 1)

        // MUT
        try await Build.find(buildId, on: app.db)?
            .delete(on: app.db)

        // validate
        try await XCTAssertEqualAsync(try await Version.query(on: app.db).count(), 1)
        try await XCTAssertEqualAsync(try await Build.query(on: app.db).count(), 0)
        try await XCTAssertEqualAsync(try await DocUpload.query(on: app.db).count(), 0)
    }

    func test_delete_cascade_version() async throws {
        // setup
        let pkg = try await savePackageAsync(on: app.db, "1")
        let versionId = UUID()
        let v = try Version(id: versionId, package: pkg)
        try await v.save(on: app.db)
        let b = try Build(id: UUID(), version: v, platform: .linux, status: .ok, swiftVersion: .v5_7)
        try await b.save(on: app.db)
        try await DocUpload(id: UUID(), status: .ok)
            .attach(to: b, on: app.db)
        try await XCTAssertEqualAsync(try await Version.query(on: app.db).count(), 1)
        try await XCTAssertEqualAsync(try await Build.query(on: app.db).count(), 1)
        try await XCTAssertEqualAsync(try await DocUpload.query(on: app.db).count(), 1)

        // MUT
        try await Version.find(versionId, on: app.db)?
            .delete(on: app.db)

        // validate
        try await XCTAssertEqualAsync(try await Version.query(on: app.db).count(), 0)
        try await XCTAssertEqualAsync(try await Build.query(on: app.db).count(), 0)
        try await XCTAssertEqualAsync(try await DocUpload.query(on: app.db).count(), 0)
    }

    func test_unique_constraint_doc_uploads_build_id() async throws {
        // Ensure different doc_uploads cannot be attached to the same build
        // setup
        let pkg = try await savePackageAsync(on: app.db, "1")
        let v = try Version(id: UUID(), package: pkg)
        try await v.save(on: app.db)
        let b = try Build(version: v, platform: .ios, status: .ok, swiftVersion: .v5_7)
        try await b.save(on: app.db)
        try await DocUpload(id: UUID(), status: .ok)
            .attach(to: b, on: app.db)

        // MUT
        do {
            try await DocUpload(id: UUID(), status: .ok)
                .attach(to: b, on: app.db)
            XCTFail("Attaching another doc_upload to the same build must fail.")
        } catch let error as PostgresError where error.code == .uniqueViolation {
            // validate
            XCTAssert(error.description.contains(#"duplicate key value violates unique constraint "uq:doc_uploads.build_id""#), "was: \(error)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_unique_constraint_builds_doc_upload_id_1() async throws {
        // Ensure doc_upload cannot be attached to two different versions (via builds from two different versions)
        // setup
        let pkg = try await savePackageAsync(on: app.db, "1")
        let v1 = try Version(id: UUID(), package: pkg)
        try await v1.save(on: app.db)
        let v2 = try Version(id: UUID(), package: pkg)
        try await v2.save(on: app.db)
        let b1 = try Build(id: UUID(), version: v1, platform: .linux, status: .ok, swiftVersion: .v5_7)
        try await b1.save(on: app.db)
        let b2 = try Build(id: UUID(), version: v2, platform: .linux, status: .ok, swiftVersion: .v5_7)
        try await b2.save(on: app.db)
        let docUpload = try DocUpload(id: UUID(), status: .ok)
        try await docUpload.attach(to: b1, on: app.db)

        // MUT
        do {
            try await docUpload.attach(to: b2, on: app.db)
            XCTFail("Attaching same doc_upload to another build must fail.")
        } catch let error as PostgresError where error.code == .uniqueViolation {
            // validate
            XCTAssert(error.description.contains(#"duplicate key value violates unique constraint "uq:builds.doc_upload_id""#), "was: \(error)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_unique_constraint_builds_doc_upload_id_2() async throws {
        // Ensure doc_upload cannot be attached to same version more than once (via two builds from same version)
        // setup
        let pkg = try await savePackageAsync(on: app.db, "1")
        let v = try Version(id: UUID(), package: pkg)
        try await v.save(on: app.db)
        let b1 = try Build(id: UUID(), version: v, platform: .linux, status: .ok, swiftVersion: .v5_7)
        try await b1.save(on: app.db)
        let b2 = try Build(id: UUID(), version: v, platform: .ios, status: .ok, swiftVersion: .v5_7)
        try await b2.save(on: app.db)
        let docUpload = try DocUpload(id: UUID(), status: .ok)
        try await docUpload.attach(to: b1, on: app.db)

        // MUT
        do {
            try await docUpload.attach(to: b2, on: app.db)
            XCTFail("Attaching same doc_upload to another build must fail.")
        } catch let error as PostgresError where error.code == .uniqueViolation {
            // validate
            XCTAssert(error.description.contains(#"duplicate key value violates unique constraint "uq:builds.doc_upload_id""#), "was: \(error)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_unique_constraint_builds_version_id_partial() async throws {
        // Ensure no single version can reference two doc_uploads
        // setup
        let pkg = try await savePackageAsync(on: app.db, "1")
        let v = try Version(id: UUID(), package: pkg)
        try await v.save(on: app.db)
        let b1 = try Build(id: UUID(), version: v, platform: .linux, status: .ok, swiftVersion: .v5_7)
        try await b1.save(on: app.db)
        let b2 = try Build(id: UUID(), version: v, platform: .ios, status: .ok, swiftVersion: .v5_7)
        try await b2.save(on: app.db)
        let docUpload1 = try DocUpload(id: UUID(), status: .ok)
        try await docUpload1.attach(to: b1, on: app.db)
        let docUpload2 = try DocUpload(id: UUID(), status: .ok)

        // MUT
        do {
            try await docUpload2.attach(to: b2, on: app.db)
            XCTFail("Attaching to build with a version_id that already has a doc_upload must fail.")
        } catch let error as PostgresError where error.code == .uniqueViolation {
            // validate
            XCTAssert(error.description.contains(#"duplicate key value violates unique constraint "uq:builds.version_id+partial""#), "was: \(error)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
