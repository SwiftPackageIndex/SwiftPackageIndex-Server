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
import DependenciesTestSupport
import SnapshotTesting
import Testing


extension AllTests.MaintainerInfoIndexModelTests {

    @Test func badgeURL() throws {
        withDependencies {
            $0.environment.siteURL = { "https://spi.com" }
        } operation: {
            let model = MaintainerInfoIndex.Model.mock

            #expect(model.badgeURL(for: .swiftVersions) == "https://img.shields.io/endpoint?url=https%3A%2F%2Fspi.com%2Fapi%2Fpackages%2Fexample%2Fpackage%2Fbadge%3Ftype%3Dswift-versions")
            #expect(model.badgeURL(for: .platforms) == "https://img.shields.io/endpoint?url=https%3A%2F%2Fspi.com%2Fapi%2Fpackages%2Fexample%2Fpackage%2Fbadge%3Ftype%3Dplatforms")
        }
    }

    @Test func badgeMarkdown() throws {
        // Test badge markdown structure
        withDependencies {
            $0.environment.siteURL = { "https://spi.com" }
        } operation: {
            let model = MaintainerInfoIndex.Model.mock

            let badgeURL = model.badgeURL(for: .swiftVersions)
            #expect(model.badgeMarkdown(for: .swiftVersions) == "[![](\(badgeURL))](https://spi.com/example/package)")
        }
    }

    @Test func scoreCategories_dependencies() throws {
        // setup
        var model = MaintainerInfoIndex.Model.mock

        do {
            model.scoreDetails?.numberOfDependencies = 0
            let categories = model.scoreCategories()
            #expect(categories["Dependencies"]?.description == "Has no dependencies.")
        }
        do {
            model.scoreDetails?.numberOfDependencies = nil
            let categories = model.scoreCategories()
            #expect(categories["Dependencies"]?.description == "No dependency information available.")
        }
    }

}


extension [MaintainerInfoIndex.Model.PackageScore] {
    subscript(title: String) -> Element? {
        first { $0.title == title }
    }
}
