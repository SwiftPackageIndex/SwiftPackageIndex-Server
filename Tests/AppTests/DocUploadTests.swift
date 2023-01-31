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
        let b = try Build(id: buildId, version: v, platform: .linux, status: .ok, swiftVersion: .v5_7)
        try await b.save(on: app.db)
        let d = DocUpload(id: docUploadId,
                          buildId: buildId,
                          versionId: versionId,
                          error: "error",
                          fileCount: 1,
                          logGroup: "group",
                          logRegion: "region",
                          logStream: "stream",
                          mbSize: 2,
                          status: .ok)

        // MUT
        try await d.save(on: app.db)

        do { // validate
            let d = try await XCTUnwrapAsync(try await DocUpload.find(docUploadId, on: app.db))
            XCTAssertEqual(d.error, "error")
            XCTAssertEqual(d.fileCount, 1)
            XCTAssertEqual(d.logGroup, "group")
            XCTAssertEqual(d.logRegion, "region")
            XCTAssertEqual(d.logStream, "stream")
            XCTAssertEqual(d.mbSize, 2)
            XCTAssertEqual(d.status, .ok)
        }
    }

    func test_delete_cascade() throws {
        XCTFail()
    }

    func test_logUrl() throws {
        XCTFail()
    }

}
