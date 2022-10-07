// Copyright 2020-2022 Dave Verwer, Sven A. Schmidt, and other contributors.
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


enum DocumentationTarget: Equatable {
    case external(url: String)
    case `internal`(owner: String, repository: String, reference: String, archive: String)

    static func query(on database: Database, owner: String, repository: String) async throws -> Self? {
        let results = try await Joined3<Version, Package, Repository>
            .query(on: database,
                   join: \Version.$package.$id == \Package.$id, method: .inner,
                   join: \Package.$id == \Repository.$package.$id, method: .inner)
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .filter(Repository.self, \.$name, .custom("ilike"), repository)
            .group(.or) {
                $0
                    .filter(\Version.$docArchives != nil)
                    .filter(\Version.$spiManifest != nil)
            }
            .field(Repository.self, \.$ownerName)
            .field(Version.self, \.$commitDate)
            .field(Version.self, \.$docArchives)
            .field(Version.self, \.$latest)
            .field(Version.self, \.$packageName)
            .field(Version.self, \.$publishedAt)
            .field(Version.self, \.$reference)
            .field(Version.self, \.$spiManifest)
            .all()

        return results
            .map(\.model)
            .documentationTarget(owner: owner, repository: repository)
    }
}


private extension [Version] {
    var defaultBranchVersion: Version? { filter { $0.latest == .defaultBranch}.first }
    var releaseVersion: Version? { filter { $0.latest == .release}.first }

    func documentationTarget(owner: String, repository: String) -> DocumentationTarget? {
        // External documentation links have priority over generated documentation.
        if let spiManifest = defaultBranchVersion?.spiManifest,
           let documentation = spiManifest.externalLinks?.documentation {
            return .external(url: documentation)
        }

        // Ideal case is that we have a stable release documentation.
        if let version = releaseVersion,
           let archive = version.docArchives?.first?.name {
            return .internal(owner: owner,
                             repository: repository,
                             reference: "\(version.reference)",
                             archive: archive)
        }

        // Fallback is default branch documentation.
        if let version = defaultBranchVersion,
           let archive = version.docArchives?.first?.name {
            return .internal(owner: owner,
                             repository: repository,
                             reference: "\(version.reference)",
                             archive: archive)
        }

        // There is no default dodcumentation.
        return nil
    }

}


extension PackageController.PackageResult {
    var hasDocumentation: Bool { documentationTarget != nil }

    var documentationTarget: DocumentationTarget? {
        guard let owner = repository.owner, let repo = repository.name else { return .none }
        return [defaultBranchVersion.model, releaseVersion?.model, preReleaseVersion?.model]
            .compactMap { $0 }
            .documentationTarget(owner: owner, repository: repo)
    }
}


