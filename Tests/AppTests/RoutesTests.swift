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

import Dependencies
import XCTVapor


final class RoutesTests: AppTestCase {

    func test_documentation_images() async throws {
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = App.HTTPClient.echoURL()
        } operation: {
            // MUT
            try await app.test(.GET, "foo/bar/1.2.3/images/baz.png") { res async in
                // validation
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.content.contentType?.description, "application/octet-stream")
                XCTAssertEqual(res.body.asString(), "/foo/bar/1.2.3/images/baz.png")
            }
            try await app.test(.GET, "foo/bar/1.2.3/images/BAZ.png") { res async in
                // validation
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.content.contentType?.description, "application/octet-stream")
                XCTAssertEqual(res.body.asString(), "/foo/bar/1.2.3/images/BAZ.png")
            }
        }
    }

    func test_documentation_img() async throws {
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = { @Sendable _ in .ok }
        } operation: {
            // MUT
            try await app.test(.GET, "foo/bar/1.2.3/img/baz.png") { res async in
                // validation
                XCTAssertEqual(res.status, .ok)
            }
        }
    }

    func test_documentation_videos() async throws {
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = { @Sendable _ in .ok }
        } operation: {
            // MUT
            try await app.test(.GET, "foo/bar/1.2.3/videos/baz.mov") { res async in
                // validation
                XCTAssertEqual(res.status, .ok)
            }
        }
    }

    func test_openapi() async throws {
        try await app.test(.GET, "openapi/openapi.json") { res async in
            XCTAssertEqual(res.status, .ok)
            struct Response: Codable, Equatable {
                var info: Info
                struct Info: Codable, Equatable {
                    var title: String
                }
            }
            XCTAssertEqualJSON(res.body.asString(), Response(info: .init(title: "Swift Package Index API")))
        }
    }

    func test_maintenanceMessage() throws {
        try withDependencies {
            $0.environment.dbId = { nil }
        } operation: {
            Current.maintenanceMessage = { "MAINTENANCE_MESSAGE" }

            try app.test(.GET, "/") { res in
                XCTAssertContains(res.body.string, "MAINTENANCE_MESSAGE")
            }
        }
    }

}
