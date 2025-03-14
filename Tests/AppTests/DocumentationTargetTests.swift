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

@testable import App

import Testing


extension AllTests.DocumentationTargetTests {

    @Test func external() async throws {
        // Test external doc url lookup
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1".url)
            try await Repository(package: pkg,
                                 name: "bar",
                                 owner: "foo").save(on: app.db)
            let version = try App.Version(package: pkg,
                                          commit: "0123456789",
                                          commitDate: Date(timeIntervalSince1970: 0),
                                          docArchives: nil,
                                          latest: .defaultBranch,
                                          packageName: "test",
                                          reference: .branch("main"),
                                          spiManifest: .init(yml: """
                                        version: 1
                                        external_links:
                                          documentation: https://example.com/package/documentation/
                                        """))
            try await version.save(on: app.db)

            // MUT
            let res = try await DocumentationTarget.query(on: app.db, owner: "foo", repository: "bar")

            // validate
            #expect(res == .external(url: "https://example.com/package/documentation/"))
        }
    }

    @Test func external_override() async throws {
        // Test external doc url lookup overriding internal doc archives
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1".url)
            try await Repository(package: pkg,
                                 name: "bar",
                                 owner: "foo").save(on: app.db)
            let version = try App.Version(package: pkg,
                                          commit: "0123456789",
                                          commitDate: Date(timeIntervalSince1970: 0),
                                          docArchives: [
                                            // Inserting an archive here to test that the external URL overrides any generated docs.
                                            .init(name: "archive1", title: "Archive One")
                                          ],
                                          latest: .defaultBranch,
                                          packageName: "test",
                                          reference: .branch("main"),
                                          spiManifest: .init(yml: """
                                        version: 1
                                        external_links:
                                          documentation: https://example.com/package/documentation/
                                        """))
            try await version.save(on: app.db)

            // MUT
            let res = try await DocumentationTarget.query(on: app.db, owner: "foo", repository: "bar")

            // validate
            #expect(res == .external(url: "https://example.com/package/documentation/"))
        }
    }

    @Test func internal_defaultBranch() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1".url)
            try await Repository(package: pkg,
                                 name: "bar",
                                 owner: "foo").save(on: app.db)
            try await App.Version(package: pkg,
                                  commit: "0123456789",
                                  commitDate: Date(timeIntervalSince1970: 0),
                                  docArchives: [
                                    .init(name: "archive1", title: "Archive One")
                                  ],
                                  latest: .defaultBranch,
                                  packageName: "test",
                                  reference: .branch("main")).save(on: app.db)

            // MUT
            let res = try await DocumentationTarget.query(on: app.db, owner: "foo", repository: "bar")

            // validate
            #expect(res == .internal(docVersion: .reference("main"), archive: "archive1"))
        }
    }

    @Test func internal_stableBranch() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1".url)
            try await Repository(package: pkg,
                                 name: "bar",
                                 owner: "foo").save(on: app.db)
            try await App.Version(package: pkg,
                                  commit: "0000000000",
                                  commitDate: Date(timeIntervalSince1970: 0),
                                  docArchives: [
                                    .init(name: "archive1", title: "Archive One")
                                  ],
                                  latest: .defaultBranch,
                                  packageName: "test",
                                  reference: .branch("main")).save(on: app.db)
            try await App.Version(package: pkg,
                                  commit: "11111111111",
                                  commitDate: Date(timeIntervalSince1970: 0),
                                  docArchives: [
                                    .init(name: "archive2", title: "Archive Two")
                                  ],
                                  latest: .release,
                                  packageName: "test",
                                  reference: .tag(1, 0, 0)).save(on: app.db)

            // MUT
            let res = try await DocumentationTarget.query(on: app.db, owner: "foo", repository: "bar")

            // validate
            #expect(res == .internal(docVersion: .reference("1.0.0"), archive: "archive2"))
        }
    }

}
