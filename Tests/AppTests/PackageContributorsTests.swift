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

import XCTest

@testable import App

class PackageContributorsTests : AppTestCase {
  
    func test_CommitSelector_primaryContributors() throws {
        
        let candidates = [PackageContributors.Contributor(numberOfCommits: 10, name: "Tim"),
                          PackageContributors.Contributor(numberOfCommits: 100, name: "John"),
                          PackageContributors.Contributor(numberOfCommits: 900, name: "Maria"),
                          PackageContributors.Contributor(numberOfCommits: 1000, name: "Nathalie")]
        
        // MUT
        let authors = PackageContributors.primaryContributors(candidates: candidates, threshold: 0.6)
        
        XCTAssertEqual(authors.count, 2)
        XCTAssertEqual(authors.map(\.name), ["Maria", "Nathalie"] )
        
    }
    
    
    func test_CommitSelector_primaryContributors_noCandidates() throws {
        // MUT
        let authors = PackageContributors.primaryContributors(candidates: [], threshold: 0.6)
        
        XCTAssertEqual(authors.count, 0)
    }
    
    func test_CommitSelector_filter_singleCandidate() throws {
        // MUT
        let authors = PackageContributors.primaryContributors(candidates: [PackageContributors.Contributor(numberOfCommits: 10, name: "Tim")],
                                                              threshold: 0.6)
        
        XCTAssertEqual(authors.count, 1)
        XCTAssertEqual(authors.map(\.name), ["Tim"] )
    }
    

    func test_PackageContributors_extract() async throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".asGithubUrl.url)
        Current.fileManager.fileExists = { _ in true }
        Current.git.shortlog = { _ in
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
        
        guard let gitCacheDirectoryPath = Current.fileManager.cacheDirectoryPath(for: pkg) else {
            throw AppError.invalidPackageCachePath(pkg.id, pkg.url)
        }
        
        // MUT
        let pkgAuthors = try PackageContributors.extract(gitCacheDirectoryPath: gitCacheDirectoryPath, packageID: pkg.id)
        
        XCTAssertEqual(pkgAuthors.authors, [Author(name: "Person 1") ,
                                            Author(name: "Person 2"),
                                            Author(name: "Person 3"),
                                            Author(name: "Person 4"),
                                            Author(name: "Person 5")])
        XCTAssertEqual(pkgAuthors.numberOfContributors, 6)
        
    }
    
    
    

    
}
