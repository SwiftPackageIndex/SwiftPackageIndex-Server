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

import Plot

enum ExternalURL: URLRepresentable {
    case addNewPackage(_ owner: String, _ repository: String)
    case contactMailto
    case mastodon
    case podcast
    case projectGitHub
    case projectSponsorship
    case raiseNewIssue

    var description: String {
        switch(self) {
            case let .addNewPackage(owner, repository):
                return "https://github.com/SwiftPackageIndex/PackageList/issues/new?labels=Add+Package&template=add_package.yml&title=Add+\(repository)&list=https%3A%2F%2Fgithub.com%2F\(owner)%2F\(repository).git"
            case .contactMailto:
                return "mailto:contact@swiftpackageindex.com"
            case .mastodon:
                return "https://mas.to/@SwiftPackageIndex"
            case .podcast:
                return "https://swiftpackageindexing.transistor.fm"
            case .projectGitHub:
                return "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server"
            case .projectSponsorship:
                return "https://github.com/sponsors/SwiftPackageIndex"
            case .raiseNewIssue:
                return "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/new/choose"
        }
    }
}
