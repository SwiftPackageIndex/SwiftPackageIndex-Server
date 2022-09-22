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

class PackageContributorServiceTests : AppTestCase {
  
    func test_CommitSelector_filter() throws {
        
        let candidates = [Contributor(numberOfCommits: 10, email: "tim@apple.com", name: "Tim"),
                          Contributor(numberOfCommits: 100, email: "john@apple.com", name: "John"),
                          Contributor(numberOfCommits: 900, email: "maria@apple.com", name: "Maria"),
                          Contributor(numberOfCommits: 1000, email: "nathalie@apple.com", name: "Nathalie")]
        
        // MUT
        let authors = CommitSelector.filter(candidates: candidates, threshold: 0.6)
        
        XCTAssertEqual(authors.count, 2)
        XCTAssertEqual(authors.map(\.name), ["Maria", "Nathalie"] )
        
    }
    
    
    func test_CommitSelector_filter_noCandidates() throws {
        // MUT
        let authors = CommitSelector.filter(candidates: [], threshold: 0.6)
        
        XCTAssertEqual(authors.count, 0)
    }
    
    func test_CommitSelector_filter_singleCandidate() throws {
        // MUT
        let authors = CommitSelector.filter(candidates: [Contributor(numberOfCommits: 10, email: "tim@apple.com", name: "Tim")], threshold: 0.6)
        
        XCTAssertEqual(authors.count, 1)
        XCTAssertEqual(authors.map(\.name), ["Tim"] )
    }
    

    func test_PackageContributorService_authorExtractor() async throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".asGithubUrl.url)
        Current.fileManager.fileExists = { _ in true }
        Current.git.shortlog = { _ in
            """
            1000  Person 1 <person1@example.com>
             871  Person 2 <person2@example.com>
             803  Person 3 <person3@example.com>
             722  Person 4 <person4@example.com>
             703  Person 5 <person5@example.com>
             360  Person 6 <person6@example.com>
             108  Person 7 <person7@example.com>
              86  Person 8 <person8@example.com>
              43  Person 9 <person9@example.com>
              40  Person 10 <person10@example.com>
              11  Person 11 <person11@example.com>
            """
        }
        
        guard let gitCacheDirectoryPath = Current.fileManager.cacheDirectoryPath(for: pkg) else {
            throw AppError.invalidPackageCachePath(pkg.id, pkg.url)
        }
        
        // MUT
        let pkgAuthors = try PackageContributorService.authorExtractor(cacheDirPath: gitCacheDirectoryPath, packageID: pkg.id)
        
        XCTAssertEqual(pkgAuthors.authors, [Author(name: "Person 1") ,
                                            Author(name: "Person 2"),
                                            Author(name: "Person 3"),
                                            Author(name: "Person 4"),
                                            Author(name: "Person 5")])
        XCTAssertEqual(pkgAuthors.numberOfContributors, 6)
        
    }
    
    
    

    
}
