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
import SnapshotTesting


class MaintainerInfoIndexModelTests: SnapshotTestCase {

    func test_badgeURL() throws {
        Current.siteURL = { "https://spi.com" }
        let model = MaintainerInfoIndex.Model.mock

        XCTAssertEqual(model.badgeURL(for: .swiftVersions), "https://img.shields.io/endpoint?url=https%3A%2F%2Fspi.com%2Fapi%2Fpackages%2Fexample%2Fpackage%2Fbadge%3Ftype%3Dswift-versions")
        XCTAssertEqual(model.badgeURL(for: .platforms), "https://img.shields.io/endpoint?url=https%3A%2F%2Fspi.com%2Fapi%2Fpackages%2Fexample%2Fpackage%2Fbadge%3Ftype%3Dplatforms")
    }

    func test_badgeMarkdown() throws {
        // Test badge markdown structure
        Current.siteURL = { "https://spi.com" }
        let model = MaintainerInfoIndex.Model.mock

        let badgeURL = model.badgeURL(for: .swiftVersions)
        XCTAssertEqual(model.badgeMarkdown(for: .swiftVersions), "[![](\(badgeURL))](https://spi.com/example/package)")
    }

    func test_scoreCategories_dependencies() throws {
        // setup
        var model = MaintainerInfoIndex.Model.mock

        do {
            model.scoreDetails?.numberOfDependencies = 0
            let categories = model.scoreCategories
            XCTAssertEqual(categories["Dependencies"]?.description, "Has no dependencies.")
        }
        do {
            model.scoreDetails?.numberOfDependencies = nil
            let categories = model.scoreCategories
            XCTAssertEqual(categories["Dependencies"]?.description, "No dependency information available.")
        }
    }

}


extension [MaintainerInfoIndex.Model.PackageScore] {
    subscript(title: String) -> Element? {
        first { $0.title == title }
    }
}
