import Foundation

@testable import App

import DependencyResolution
import SPIManifest


#if DEBUG
extension Version {
    // Convenience initializer to set defaults for some required values to
    // make instantiation in tests simpler.
    convenience init(id: Id? = nil,
                     package: Package,
                     commit: CommitHash = "",
                     commitDate: Date = .distantPast,
                     docArchives: [DocArchive]? = nil,
                     latest: Kind? = nil,
                     packageName: String? = nil,
                     productDependencies: [ProductDependency]? = nil,
                     publishedAt: Date? = nil,
                     reference: Reference = .branch("main"),
                     releaseNotes: String? = nil,
                     releaseNotesHTML: String? = nil,
                     resolvedDependencies: [ResolvedDependency]? = nil,
                     spiManifest: SPIManifest.Manifest? = nil,
                     supportedPlatforms: [App.Platform] = [],
                     swiftVersions: [App.SwiftVersion] = [],
                     toolsVersion: String? = nil,
                     url: String? = nil) throws {
        self.init()
        self.id = id
        self.$package.id = try package.requireID()
        self.commit = commit
        self.commitDate = commitDate
        self.docArchives = docArchives
        self.latest = latest
        self.packageName = packageName
        self.productDependencies = productDependencies
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
}
#endif
