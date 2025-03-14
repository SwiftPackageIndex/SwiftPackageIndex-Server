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

import Dependencies
import Testing


extension AllTests.RoutesTests {

    @Test func documentation_images() async throws {
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = App.HTTPClient.echoURL()
        } operation: {
            try await withApp { app in
                // MUT
                try await app.test(.GET, "foo/bar/1.2.3/images/baz.png") { res async in
                    // validation
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "application/octet-stream")
                    #expect(res.body.asString() == "/foo/bar/1.2.3/images/baz.png")
                }
                try await app.test(.GET, "foo/bar/1.2.3/images/BAZ.png") { res async in
                    // validation
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "application/octet-stream")
                    #expect(res.body.asString() == "/foo/bar/1.2.3/images/BAZ.png")
                }
            }
        }
    }

    @Test func documentation_img() async throws {
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = { @Sendable _ in .ok }
        } operation: {
            try await withApp { app in
                // MUT
                try await app.test(.GET, "foo/bar/1.2.3/img/baz.png") { res async in
                    // validation
                    #expect(res.status == .ok)
                }
            }
        }
    }

    @Test func documentation_videos() async throws {
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = { @Sendable _ in .ok }
        } operation: {
            try await withApp { app in
                // MUT
                try await app.test(.GET, "foo/bar/1.2.3/videos/baz.mov") { res async in
                    // validation
                    #expect(res.status == .ok)
                }
            }
        }
    }

    @Test func maintenanceMessage() async throws {
        try await withDependencies {
            $0.environment.dbId = { nil }
            $0.environment.maintenanceMessage = { "MAINTENANCE_MESSAGE" }
        } operation: {
            try await withApp { app in
                try await app.test(.GET, "/") { res async in
                    #expect(res.body.string.contains("MAINTENANCE_MESSAGE"))
                }
            }
        }
    }

}
