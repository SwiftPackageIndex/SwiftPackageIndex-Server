import Fluent
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
    var commit: CommitHash?
    
    @Field(key: "commit_date")
    var commitDate: Date?

    @Field(key: "latest")
    var latest: Kind?

    @Field(key: "package_name")
    var packageName: String?

    @Field(key: "published_at")
    var publishedAt: Date?

    @Field(key: "reference")
    var reference: Reference?

    @Field(key: "release_notes")
    var releaseNotes: String?

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
         commit: CommitHash? = nil,
         commitDate: Date? = nil,
         latest: Kind? = nil,
         packageName: String? = nil,
         publishedAt: Date? = nil,
         reference: Reference? = nil,
         releaseNotes: String? = nil,
         supportedPlatforms: [Platform] = [],
         swiftVersions: [SwiftVersion] = [],
         toolsVersion: String? = nil,
         url: String? = nil) throws {
        self.id = id
        self.$package.id = try package.requireID()
        self.commit = commit
        self.commitDate = commitDate
        self.latest = latest
        self.packageName = packageName
        self.publishedAt = publishedAt
        self.reference = reference
        self.releaseNotes = releaseNotes
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
        lhs.id == rhs.id
    }
}


extension Version {
    func supportsMajorSwiftVersion(_ swiftVersion: Int) -> Bool {
        Self.supportsMajorSwiftVersion(swiftVersion, values: swiftVersions)
    }
    
    static func supportsMajorSwiftVersion(_ swiftVersion: Int, value: SwiftVersion) -> Bool {
        return value.major >= swiftVersion
    }
    
    static func supportsMajorSwiftVersion(_ swiftVersion: Int, values: [SwiftVersion]) -> Bool {
        values.first { supportsMajorSwiftVersion(swiftVersion, value: $0) } != nil
    }
}


// MARK: - Relationship helpers

extension Version {

    /// Fetches associated package relationship (if not already loaded).
    /// - Parameters:
    ///   - db: database object
    /// - Returns: `Package` future
    func fetchPackage(_ db: Database) -> EventLoopFuture<Package> {
        if let package = $package.value {
            return db.eventLoop.future(package)
        }
        return $package.load(on: db).map { self.package }
    }

}

// MARK: - Version reconciliation / diffing

extension Version {
    struct ImmutableReference: Equatable, Hashable {
        var reference: Reference
        var commit: CommitHash
    }
    
    var immutableReference: ImmutableReference? {
        guard let ref = reference, let commit = commit else { return nil }
        return .init(reference: ref, commit: commit)
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
        let delta = diff(local: local.compactMap(\.immutableReference),
                         incoming: incoming.compactMap(\.immutableReference))
        return .init(
            toAdd: incoming.filter { $0.immutableReference.map({delta.toAdd.contains($0)}) ?? false },
            toDelete: local.filter { $0.immutableReference.map({delta.toDelete.contains($0)}) ?? false },
            toKeep: local.filter { $0.immutableReference.map({delta.toKeep.contains($0)}) ?? false }
        )
    }
}
