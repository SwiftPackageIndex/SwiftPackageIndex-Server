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

import Fluent
import SemanticVersion
@preconcurrency import SPIManifest


struct DocumentationMetadata {
    var owner: String?
    var repository: String?
    var canonicalTarget: DocumentationTarget?
    var versions: [DocumentationVersion]

    static func query(on database: Database, owner: String, repository: String) async throws -> Self {
        let results = try await Joined3<Version, Package, Repository>
            .query(on: database,
                   join: \Version.$package.$id == \Package.$id, method: .inner,
                   join: \Package.$id == \Repository.$package.$id, method: .inner)
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .filter(Repository.self, \.$name, .custom("ilike"), repository)
            .filter(\Version.$docArchives != nil)
            .field(Version.self, \.$reference)
            .field(Version.self, \.$latest)
            .field(Version.self, \.$packageName)
            .field(Version.self, \.$docArchives)
            .field(Version.self, \.$commitDate)
            .field(Version.self, \.$publishedAt)
            .field(Version.self, \.$spiManifest)
            .field(Repository.self, \.$owner)
            .field(Repository.self, \.$name)
            .field(Repository.self, \.$ownerName)
            .all()

        // This query returns `Version` objects that have nil `latest` properties as we show documentation
        // for major package versions that are *not* latest anything. There's no need to filter these records
        // out as they are never selected by `canonicalDocumentationTarget` but it's worth being aware that
        // this is normal and expected.
        let versions = results.map {$0.model }
        let canonicalDocumentationTarget = versions.canonicalDocumentationTarget()

        let documentationVersions = results.map { result -> DocumentationVersion in
                .init(reference: result.model.reference,
                      ownerName: result.relation2?.ownerName ?? owner,
                      packageName: result.model.packageName ?? repository,
                      docArchives: result.model.docArchives ?? [],
                      latest: result.model.latest,
                      updatedAt: result.model.publishedAt ?? result.model.commitDate)
        }

        return .init(owner: results.first?.relation2?.owner,
                     repository: results.first?.relation2?.name,
                     canonicalTarget: canonicalDocumentationTarget,
                     versions: documentationVersions)
    }
}

struct DocumentationVersion: Equatable {
    var reference: Reference
    var ownerName: String
    var packageName: String
    var docArchives: [DocArchive]
    var latest: Version.Kind?
    var updatedAt: Date
}

extension Array where Element == DocumentationVersion {
    subscript(reference reference: String) -> Element? {
        first { $0.reference.pathEncoded == reference.pathEncoded }
    }

    func latestMajorVersions() -> Self {
        let stableVersions = self.filter { version in
            guard let semVer = version.reference.semVer else { return false }
            return semVer.isStable
        }
        let groupedStableVersions = Dictionary.init(grouping: stableVersions) { version in
            version.reference.semVer?.major
        }

        return groupedStableVersions.compactMap { key, versions -> Element? in
            // If any of the references had a nil semVer then there could be a nil key in the dictionary.
            guard key != nil else { return nil }

            // Filter down to only the largest semVer in each group.
            let latestMajorStableVersion = versions
                .compactMap { result -> (result: Element, semVer: SemanticVersion)? in
                    guard let semVer = result.reference.semVer else { return nil }
                    return (result: result, semVer: semVer)
                }
                .sorted { $0.semVer > $1.semVer }
                .first?
                .result

            return latestMajorStableVersion
        }
        .sorted { firstVersion, secondVersion in
            guard let firstSemVer = firstVersion.reference.semVer,
                  let secondSemVer = secondVersion.reference.semVer
            else { return false }

            return firstSemVer < secondSemVer
        }
    }
}
