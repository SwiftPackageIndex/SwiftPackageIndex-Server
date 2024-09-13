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

import Fluent
import SQLKit
import Vapor

extension API.PackageController {
     enum ForkedFromResult {
        case fromSPI(repository: String, owner: String, ownerName: String, packageName: String)
        case fromGitHub(url: String)
        
        static func query(on database: Database, packageId: Package.Id) async throws -> ForkedFromResult? {
            let model = try await Joined3<Package, Repository, Version>
                .query(on: database, packageId: packageId, version: .defaultBranch)
                .first()

            guard let repoName = model?.repository.name,
                  let ownerName = model?.repository.ownerName,
                  let owner = model?.repository.owner else {
                return nil
            }
            
            // fallback to repo name if packageName is nil
            let packageName: String = model?.version.packageName ?? repoName

            return ForkedFromResult.fromSPI(
                repository: repoName,
                owner: owner,
                ownerName: ownerName,
                packageName: packageName
            )
        }
    }
}
