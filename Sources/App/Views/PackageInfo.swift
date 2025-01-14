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

struct PackageInfo {
    var title: String
    var description: String
    var repositoryOwner: String
    var repositoryName: String
    var url: String
    var stars: Int
    var lastActivityAt: Date?
    var hasDocs: Bool?
}

extension PackageInfo {
    init?(package: Joined3<Package, Repository, Version>) {
        guard let repoName = package.repository.name,
              let repoOwner = package.repository.owner
        else { return nil }

        let title = package.version.packageName ?? repoName

        self.init(title: title,
                  description: package.repository.summary ?? "",
                  repositoryOwner: repoOwner,
                  repositoryName: repoName,
                  url: SiteURL.package(.value(repoOwner), .value(repoName), .none).relativeURL(),
                  stars: package.repository.stars,
                  lastActivityAt: package.repository.lastActivityAt,
                  hasDocs: package.model.scoreDetails?.hasDocumentation ?? false
        )
    }
}
