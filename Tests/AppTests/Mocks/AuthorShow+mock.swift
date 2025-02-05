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

import Foundation


extension AuthorShow.Model {
    static var mock: AuthorShow.Model {
        let packages = (1...10).map { PackageInfo(
            title: "vapor-\($0)",
            description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas nec orci scelerisque, interdum purus a, tempus turpis.",
            repositoryOwner: "owner",
            repositoryName: "name",
            url: "https://example.com/owner/name.git",
            stars: 3,
            lastActivityAt: .t0,
            hasDocs: true
        ) }
        return .init(owner: "test-author", ownerName: "Test Author", packages: packages)
    }
}
