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
import Vapor


extension AllTests.LiveTests {

    @Test(
        .disabled("Only run this test manually to confirm posting works")
    )
    func Mastodon_post() async throws {
        try await withDependencies {
            $0.environment.mastodonCredentials = { .dev }
            $0.httpClient = .liveValue
            $0.uuid = .init(UUID.init)
        } operation: {
            let message = Social.versionUpdateMessage(
                packageName: "packageName",
                repositoryOwnerName: "owner",
                url: "http://localhost:8080/owner/SomePackage",
                version: .init(2, 6, 4),
                summary: "Testing, testing αβγ ÄÖÜß 🔤 ✅",
                maxLength: Social.postMaxLength
            )

            try await Mastodon.post(message: message)
        }
    }

}


extension Mastodon.Credentials {
    // https://mas.to/@spi_test
    static var dev: Self? {
        guard let accessToken = Environment.get("DEV_MASTODON_ACCESS_TOKEN") else { return nil }
        return .init(accessToken: accessToken)
    }
}
