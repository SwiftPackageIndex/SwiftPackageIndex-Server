// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import DependencyResolution
import Fluent
import SPIManifest
import Vapor


typealias CommitHash = String


final class Version: Model, Content {
    static let schema = "versions"

    typealias Id = UUID

    // managed fields

    @ID(key: .id)
    var id: Id?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    // reference fields

    @Parent(key: "package_id")
    var package: Package

    // data fields

    @Field(key: "commit")
    var commit: CommitHash

    @Field(key: "commit_date")
    var commitDate: Date

    @Field(key: "doc_archives")
    var docArchives: [DocArchive]?

    @Field(key: "latest")
    var latest: Kind?

    @Field(key: "package_name")
    var packageName: String?

    @Field(key: "published_at")
    var publishedAt: Date?

    @Field(key: "reference")
    var reference: Reference

    @Field(key: "release_notes")
    var releaseNotes: String?

    @Field(key: "release_notes_html")
    var releaseNotesHTML: String?

    @Field(key: "resolved_dependencies")
    var resolvedDependencies: [ResolvedDependency]?

    @Field(key: "spi_manifest")
    var spiManifest: SPIManifest.Manifest?

    // TODO: rename to minimumPlatformVersions?
    @Field(key: "supported_platforms")
    var supportedPlatforms: [Platform]

    @Field(key: "swift_versions")
    var swiftVersions: [SwiftVersion]

    @Field(key: "tools_version")
    var toolsVersion: String?

    @Field(key: "url")
    var url: String?

    // relationships

    @Children(for: \.$version)
    var builds: [Build]

    @Children(for: \.$version)
    var products: [Product]

    @Children(for: \.$version)
    var targets: [Target]

    init() { }

    init(id: Id? = nil,
         package: Package,
         commit: CommitHash,
         commitDate: Date,
         docArchives: [DocArchive]? = nil,
         latest: Kind? = nil,
         packageName: String? = nil,
         publishedAt: Date? = nil,
         reference: Reference,
         releaseNotes: String? = nil,
         releaseNotesHTML: String? = nil,
         resolvedDependencies: [ResolvedDependency] = [],
         spiManifest: SPIManifest.Manifest? = nil,
         supportedPlatforms: [Platform] = [],
         swiftVersions: [SwiftVersion] = [],
         toolsVersion: String? = nil,
         url: String? = nil) throws {
        self.id = id
        self.$package.id = try package.requireID()
        self.commit = commit
        self.commitDate = commitDate
        self.docArchives = docArchives
        self.latest = latest
        self.packageName = packageName
        self.publishedAt = publishedAt
        self.reference = reference
        self.releaseNotes = releaseNotes
        self.releaseNotesHTML = releaseNotesHTML
        self.resolvedDependencies = resolvedDependencies
        self.spiManifest = spiManifest
        self.supportedPlatforms = supportedPlatforms
        self.swiftVersions = swiftVersions
        self.toolsVersion = toolsVersion
        self.url = url
    }

    enum Kind: String, Codable {
        case defaultBranch = "default_branch"
        case preRelease = "pre_release"
        case release
    }
}


extension Version: Equatable {
    static func == (lhs: Version, rhs: Version) -> Bool {
        if let id1 = lhs.id, let id2 = rhs.id {
            return id1 == id2
        } else {
            return lhs.commit == rhs.commit
            && lhs.commitDate == rhs.commitDate
            && lhs.reference == rhs.reference
        }
    }
}


// MARK: - Branch related helpers/properties

extension Version {
    var isBranch: Bool { reference.isBranch }
    var isTag: Bool { reference.isTag }
}


// MARK: - Version reconciliation / diffing


struct VersionDelta: Equatable {
    var toAdd: [Version] = []
    var toDelete: [Version] = []
    var toKeep: [Version] = []
}


extension Version {
    struct ImmutableReference: Equatable, Hashable {
        var reference: Reference
        var commit: CommitHash
    }

    var immutableReference: ImmutableReference {
        return .init(reference: reference, commit: commit)
    }

    static func diff(local: [Version.ImmutableReference],
                     incoming: [Version.ImmutableReference]) -> (toAdd: Set<Version.ImmutableReference>,
                                                                 toDelete: Set<Version.ImmutableReference>,
                                                                 toKeep: Set<Version.ImmutableReference>) {
        let local = Set(local)
        let incoming = Set(incoming)
        return (toAdd: incoming.subtracting(local),
                toDelete: local.subtracting(incoming),
                toKeep: local.intersection(incoming))
    }

    static func diff(local: [Version], incoming: [Version]) -> VersionDelta {
        let delta = diff(local: local.map(\.immutableReference),
                         incoming: incoming.map(\.immutableReference))
        return .init(
            toAdd: incoming.filter { delta.toAdd.contains($0.immutableReference) },
            toDelete: local.filter { delta.toDelete.contains($0.immutableReference) },
            toKeep: local.filter { delta.toKeep.contains($0.immutableReference) }
        )
    }
}


extension Array where Element == Version {
    // Helper to determine latest branch version in a batch
    var latestBranchVersion: Version? {
        filter(\.isBranch)
            .sorted { $0.commitDate < $1.commitDate }
            .last
    }
}
