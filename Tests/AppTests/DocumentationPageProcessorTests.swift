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

import XCTest

@testable import App

import SnapshotTesting


final class DocumentationPageProcessorTests: AppTestCase {

    func test_header_linkTitle() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2249
        // setup
        let coreArchive = DocArchive(name: "tecocore", title: "TecoCore")
        let signerArchive = DocArchive(name: "tecosigner", title: "Teco Signer")
        let archives: [DocumentationPageProcessor.AvailableArchive] = [
            .init(archive: coreArchive, isCurrent: false),
            .init(archive: signerArchive, isCurrent: true)
        ]
        let processor = try XCTUnwrap(
            DocumentationPageProcessor(
                repositoryOwner: "owner",
                repositoryOwnerName: "Owner Name",
                repositoryName: "repo",
                packageName: "package",
                reference: "main",
                referenceLatest: .release,
                referenceKind: .release,
                canonicalUrl: "https://example.com/owner/repo/canonical-ref",
                availableArchives: archives,
                availableVersions: [
                    .init(
                        kind: .defaultBranch,
                        reference: "main",
                        docArchives: [coreArchive, signerArchive],
                        isLatestStable: false
                    )
                ],
                updatedAt: .t0,
                rawHtml: try fixtureString(for: "docc-template.html")
            )
        )

        // MUT & validate
        assertSnapshot(matching: processor.header, as: .html)
    }

}
