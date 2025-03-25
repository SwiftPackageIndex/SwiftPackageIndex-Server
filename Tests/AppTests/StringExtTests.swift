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

import Testing


extension AllTests.StringExtTests {

    @Test func pluralised() throws {
        #expect("version".pluralized(for: 0) == "versions")
        #expect("version".pluralized(for: 1) == "version")
        #expect("version".pluralized(for: 2) == "versions")

        #expect("library".pluralized(for: 0, plural: "libraries") == "libraries")
        #expect("library".pluralized(for: 1, plural: "libraries") == "library")
        #expect("library".pluralized(for: 2, plural: "libraries") == "libraries")
    }

    @Test func droppingGitSuffix() {
        #expect(
            "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server".droppingGitExtension == "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server"
        )

        #expect(
            "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server.git".droppingGitExtension == "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server"
        )
    }

    @Test func droppingGitHubPrefix() {
        #expect(
            "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server".droppingGithubComPrefix == "SwiftPackageIndex/SwiftPackageIndex-Server"
        )
    }

    @Test func trimming() {
        #expect("".trimmed == nil)
        #expect("  ".trimmed == nil)
        #expect(" string ".trimmed == "string")
        #expect("string".trimmed == "string")
    }

    @Test func removingSuffix() throws {
        #expect("".removingSuffix("") == "")
        #expect("".removingSuffix("bob") == "")
        #expect("bob".removingSuffix("bob") == "")
        #expect("bobby and bob".removingSuffix("bob") == "bobby and ")
        #expect("bobby and bob ".removingSuffix("bob") == "bobby and bob ")
        #expect("Bobby and Bob".removingSuffix("bob") == "Bobby and ")
        #expect("bobby and bob".removingSuffix("Bob") == "bobby and ")
    }

    @Test func sha256Checksum() throws {
        #expect("foo".sha256Checksum == "2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae")
    }

}
