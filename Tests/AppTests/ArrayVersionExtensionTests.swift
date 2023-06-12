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

import SemanticVersion
import SPIManifest

class ArrayVersionExtensionTests: AppTestCase {

    func test_Array_canonicalDocumentationTarget() async throws {
        let pkg = try await savePackageAsync(on: app.db, "1".url)
        let archive = DocArchive(name: "foo", title: "Foo")

        do {
            // [ Default branch, nil, nil ] = Default branch
            let versions = [
                try Version(package: pkg,
                            commit: "123",
                            commitDate: .t0,
                            docArchives: [archive],
                            latest: .defaultBranch,
                            reference: .branch("main"),
                            spiManifest: nil),
                nil,
                nil
            ]

            XCTAssertEqual(versions.canonicalDocumentationTarget(),
                           .internal(reference: "main", archive: "foo"))
        }

        do {
            // [ Default branch (with docs), Release (no docs), nil ] = Release
            let versions = [
                try Version(package: pkg,
                            commit: "123",
                            commitDate: .t0,
                            docArchives: [archive],
                            latest: .defaultBranch,
                            reference: .branch("main"),
                            spiManifest: nil),
                try Version(package: pkg,
                            docArchives: nil,
                            latest: .release,
                            reference: .tag(SemanticVersion(1, 2, 3))),
                nil
            ]

            XCTAssertEqual(versions.canonicalDocumentationTarget(),
                           .internal(reference: "main", archive: "foo"))
        }

        do {
            // [ Default branch (with docs), nil, Release (with docs) ] = Release
            let versions = [
                try Version(package: pkg,
                            commit: "123",
                            commitDate: .t0,
                            docArchives: [archive],
                            latest: .defaultBranch,
                            reference: .branch("main"),
                            spiManifest: nil),
                nil,
                try Version(package: pkg,
                            docArchives: [archive],
                            latest: .release,
                            reference: .tag(SemanticVersion(1, 2, 3)))
            ]

            XCTAssertEqual(versions.canonicalDocumentationTarget(),
                           .internal(reference: "1.2.3", archive: "foo"))
        }

        do {
            // [ Default branch (with docs), Pre-Release (with docs), nil ] = Pre-Release
            let versions = [
                try Version(package: pkg,
                            commit: "123",
                            commitDate: .t0,
                            docArchives: [archive],
                            latest: .defaultBranch,
                            reference: .branch("main"),
                            spiManifest: nil),
                try Version(package: pkg,
                            docArchives: [archive],
                            latest: .preRelease,
                            reference: .tag(SemanticVersion(1, 2, 3, "b1"))),
                nil
            ]

            XCTAssertEqual(versions.canonicalDocumentationTarget(),
                           .internal(reference: "1.2.3-b1", archive: "foo"))
        }

        do {
            // [ Default branch (with docs), Pre-Release (with docs), Release (with docs) ] = Release
            let versions = [
                try Version(package: pkg,
                            commit: "123",
                            commitDate: .t0,
                            docArchives: [archive],
                            latest: .defaultBranch,
                            reference: .branch("main"),
                            spiManifest: nil),
                try Version(package: pkg,
                            docArchives: [archive],
                            latest: .preRelease,
                            reference: .tag(SemanticVersion(1, 2, 3, "b1"))),
                try Version(package: pkg,
                            docArchives: [archive],
                            latest: .release,
                            reference: .tag(SemanticVersion(1, 2, 3)))
            ]

            XCTAssertEqual(versions.canonicalDocumentationTarget(),
                           .internal(reference: "1.2.3", archive: "foo"))
        }

        do {
            // [ Default branch (no docs), nil, Release (with docs) ] = Release
            let versions = [
                try Version(package: pkg,
                            commit: "123",
                            commitDate: .t0,
                            docArchives: nil,
                            latest: .defaultBranch,
                            reference: .branch("main"),
                            spiManifest: nil),
                nil,
                try Version(package: pkg,
                            docArchives: [archive],
                            latest: .release,
                            reference: .tag(SemanticVersion(1, 2, 3)))
            ]

            XCTAssertEqual(versions.canonicalDocumentationTarget(),
                           .internal(reference: "1.2.3", archive: "foo"))
        }

        do {
            // [ Default branch (with external docs), Pre-Release (with docs), Release (with docs) ] = External docs
            let versions = [
                try Version(package: pkg,
                            commit: "123",
                            commitDate: .t0,
                            docArchives: [archive],
                            latest: .defaultBranch,
                            reference: .branch("main"),
                            spiManifest: .init(externalLinks: .init(documentation: "https://example.com"))),
                try Version(package: pkg,
                            docArchives: [archive],
                            latest: .preRelease,
                            reference: .tag(SemanticVersion(1, 2, 3, "b1"))),
                try Version(package: pkg,
                            docArchives: [archive],
                            latest: .release,
                            reference: .tag(SemanticVersion(1, 2, 3)))
            ]

            XCTAssertEqual(versions.canonicalDocumentationTarget(),
                           .external(url: "https://example.com"))
        }
    }
}
