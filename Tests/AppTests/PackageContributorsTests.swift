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

import Dependencies
import Testing


extension AllTests.PackageContributorsTests  {

    @Test func packageAuthors_hasAuthors() throws {
        let noPackageAuthors = PackageAuthors(authors: [], numberOfContributors: 0)

        let somePackageAuthors = PackageAuthors(authors: [
            .init(name: "Person One"),
            .init(name: "Person Two")
        ], numberOfContributors: 0)

        #expect(!noPackageAuthors.hasAuthors)
        #expect(somePackageAuthors.hasAuthors)
    }

    @Test func CommitSelector_primaryContributors() throws {

        let candidates = [PackageContributors.Contributor(numberOfCommits: 10, name: "Tim"),
                          PackageContributors.Contributor(numberOfCommits: 100, name: "John"),
                          PackageContributors.Contributor(numberOfCommits: 900, name: "Maria"),
                          PackageContributors.Contributor(numberOfCommits: 1000, name: "Nathalie")]

        // MUT
        let authors = PackageContributors.primaryContributors(candidates: candidates, threshold: 0.6)

        #expect(authors.count == 2)
        #expect(authors.map(\.name) == ["Maria", "Nathalie"] )

    }

    @Test func CommitSelector_primaryContributors_noCandidates() throws {
        // MUT
        let authors = PackageContributors.primaryContributors(candidates: [], threshold: 0.6)

        #expect(authors.count == 0)
    }

    @Test func CommitSelector_filter_singleCandidate() throws {
        // MUT
        let authors = PackageContributors
            .primaryContributors(candidates: [PackageContributors.Contributor(numberOfCommits: 10,
                                                                              name: "Tim")],
                                 threshold: 0.6)

        #expect(authors.count == 1)
        #expect(authors.map(\.name) == ["Tim"] )
    }

    @Test func PackageContributors_extract() async throws {
        try await withDependencies {
            $0.fileManager.fileExists = { @Sendable _ in true }
            $0.git.shortlog = { @Sendable _ in
                """
                1000\tPerson 1
                 871\tPerson 2
                 803\tPerson 3
                 722\tPerson 4
                 703\tPerson 5
                 360\tPerson 6
                 108\tPerson 7
                  86\tPerson 8
                  43\tPerson 9
                  40\tPerson 10
                  11\tPerson 11
                """
            }
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1".asGithubUrl.url)

                // MUT
                let pkgAuthors = try await PackageContributors.extract(gitCacheDirectoryPath: "",
                                                                       packageID: pkg.id)

                #expect(pkgAuthors.authors == [Author(name: "Person 1") ,
                                               Author(name: "Person 2"),
                                               Author(name: "Person 3"),
                                               Author(name: "Person 4"),
                                               Author(name: "Person 5")])
                #expect(pkgAuthors.numberOfContributors == 6)
            }
        }
    }





}
