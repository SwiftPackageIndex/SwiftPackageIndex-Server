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

import NIO
import SPIManifest
import Testing


extension AllTests.ArrayExtensionTests {

    @Test func defaultBranchVersion() throws {
        #expect(
            [
                Version(id: .id0, latest: .release),
                Version(id: .id1, latest: .defaultBranch)
            ].defaultBranchVersion?.id == .id1
        )
        #expect(
            [
                Version(id: .id0, latest: .release),
                Version(id: .id1, latest: .preRelease),
            ].defaultBranchVersion?.id == nil
        )
    }

    @Test func releaseVersion() throws {
        #expect(
            [
                Version(id: .id0, latest: .defaultBranch),
                Version(id: .id1, latest: .release)
            ].releaseVersion?.id == .id1
        )
        #expect(
            [
                Version(id: .id0, latest: .defaultBranch),
                Version(id: .id1, latest: .preRelease),
            ].releaseVersion?.id == nil
        )
    }

    @Test func documentationTarget_external() throws {
        // Test with only external link
        #expect(
            [
                Version(id: .id0, latest: .release),
                Version(id: .id1, latest: .defaultBranch, spiManifest: .withExternalDocLink("link")),
            ].canonicalDocumentationTarget() == .external(url: "link")
        )

        // Test external link overrides generated docs
        #expect(
            [
                Version(id: .id0, latest: .release),
                Version(id: .id1, latest: .defaultBranch,
                        spiManifest: .withExternalDocLink("link"),
                        docArchives: [.init(name: "foo", title: "Foo")]),
            ].canonicalDocumentationTarget() == .external(url: "link")
        )

        // Test external link overrides generated docs, also if they're release docs
        #expect(
            [
                Version(id: .id0, latest: .release,
                        docArchives: [.init(name: "foo", title: "Foo")]),
                Version(id: .id1, latest: .defaultBranch,
                        spiManifest: .withExternalDocLink("link")),
            ].canonicalDocumentationTarget() == .external(url: "link")
        )
    }

    @Test func documentationTarget_internal() throws {
        // Test default path - release docs available
        #expect(
            [
                Version(id: .id0, latest: .release, reference: .tag(1, 2, 3),
                        docArchives: [.init(name: "foo", title: "Foo")]),
            ].canonicalDocumentationTarget() == .internal(docVersion: .reference("1.2.3"), archive: "foo")
        )

        // Test default branch fallback
        #expect(
            [
                Version(id: .id0, latest: .release, reference: .tag(1, 2, 3)),
                Version(id: .id0, latest: .defaultBranch, reference: .branch("main"),
                        docArchives: [.init(name: "foo", title: "Foo")]),
            ].canonicalDocumentationTarget() == .internal(docVersion: .reference("main"), archive: "foo")
        )

        // No default branch version available
        #expect(
            [
                Version(id: .id0, latest: .release, reference: .tag(1, 2, 3)),
            ].canonicalDocumentationTarget() == nil
        )

        // No doc archives available at all
        #expect(
            [
                Version(id: .id0, latest: .release, reference: .tag(1, 2, 3)),
                Version(id: .id0, latest: .defaultBranch, reference: .branch("main")),
            ].canonicalDocumentationTarget() == nil
        )

        // Or simply no versions in array at all
        #expect([Version]().canonicalDocumentationTarget() == nil)
    }

}


private extension Version {
    convenience init(id: Version.Id,
                     latest: Version.Kind,
                     reference: Reference? = nil,
                     spiManifest: SPIManifest.Manifest? = nil,
                     docArchives: [DocArchive]? = nil) {
        self.init()
        self.id = id
        if let reference {
            self.reference = reference
        }
        self.spiManifest = spiManifest
        self.docArchives = docArchives
        self.latest = latest
    }
}


private extension SPIManifest.Manifest {
    static func withExternalDocLink(_ link: String) -> Self {
        .init(externalLinks: .init(documentation: link))
    }
}
