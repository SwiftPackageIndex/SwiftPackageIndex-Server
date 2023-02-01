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


final class DocUploadTests: AppTestCase {

    func test_save() async throws {
        // setup
        let pkg = try await savePackageAsync(on: app.db, "1")
        let versionId = UUID()
        let buildId = UUID()
        let docUploadId = UUID()
        let v = try Version(id: versionId, package: pkg)
        try await v.save(on: app.db)
        try await Build(id: buildId, version: v, platform: .linux, status: .ok, swiftVersion: .v5_7)
            .save(on: app.db)
        let d = DocUpload(id: docUploadId,
                          buildId: buildId,
                          versionId: versionId,
                          error: "error",
                          fileCount: 1,
                          logUrl: "logUrl",
                          mbSize: 2,
                          status: .ok)

        // MUT
        try await d.save(on: app.db)

        do { // validate
            let d = try await XCTUnwrapAsync(try await DocUpload.find(docUploadId, on: app.db))
            XCTAssertEqual(d.error, "error")
            XCTAssertEqual(d.fileCount, 1)
            XCTAssertEqual(d.logUrl, "logUrl")
            XCTAssertEqual(d.mbSize, 2)
            XCTAssertEqual(d.status, .ok)
        }
    }

    func test_delete_cascade_build() async throws {
        // setup
        let pkg = try await savePackageAsync(on: app.db, "1")
        let versionId = UUID()
        let buildId = UUID()
        let v = try Version(id: versionId, package: pkg)
        try await v.save(on: app.db)
        try await Build(id: buildId, version: v, platform: .linux, status: .ok, swiftVersion: .v5_7)
            .save(on: app.db)
        try await DocUpload(buildId: buildId, versionId: versionId, status: .ok)
            .save(on: app.db)
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
        let buildId = UUID()
        let v = try Version(id: versionId, package: pkg)
        try await v.save(on: app.db)
        try await Build(id: buildId, version: v, platform: .linux, status: .ok, swiftVersion: .v5_7)
            .save(on: app.db)
        try await DocUpload(buildId: buildId, versionId: versionId, status: .ok)
            .save(on: app.db)
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

    func test_prevent_inconsistent_ids() async throws {
        // setup
        let pkg = try await savePackageAsync(on: app.db, "1")
        let versionId1 = UUID()
        let v1 = try Version(id: versionId1, package: pkg)
        try await v1.save(on: app.db)
        let versionId2 = UUID()
        let v2 = try Version(id: versionId2, package: pkg)
        try await v2.save(on: app.db)
        let buildId = UUID()
        try await Build(id: buildId, version: v1, platform: .linux, status: .ok, swiftVersion: .v5_7)
            .save(on: app.db)

        // MUT
        do {
            // Construct and attempt to save DocUpload record with inconsistent build and version ids
            try await DocUpload(buildId: buildId, versionId: versionId2, status: .ok)
                .save(on: app.db)
            XCTFail("Saving bad doc upload record must fail")
        } catch {
            XCTAssertEqual("\(error)", "")
        }

        // validate
    }

}
