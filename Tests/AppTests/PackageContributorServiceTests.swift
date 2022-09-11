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
            1000  Rick Sanchez <rick@gmail.com>
             871  Morty Smith <Morty@bluebite.com>
             803  Summer Smith <Summer@orlandos.nl>
             722  Beth Smith <Beth@tanner.xyz>
             703  Summer <sexy@tanner.xyz>
             360  Rick <ricko@tanner.xyz>
             108  Jessica <jessi@gmail.com>
              86  Birdperson <birdie@gmail.com>
              43  Noob Noob  <n00b@weebly.com>
              40  Jerry Smith <jerryS@users.noreply.github.com>
              30  Jerry <jerry@yahoo.com>
              29  Pickle Rick <skankingPickle@darkrainfall.org>
              21  Squanchy <squanchy@gmail.com>
              19  Planetina <planetina@hilenium.com>
              19  The Vindicators <thevindicathors@users.noreply.github.com>
              18  Nathalie <bitbucket@nathi.com>
              16  Tricia Lange <tricia@users.noreply.github.com>
              15  Naruto Smith <naruto@jarict.nl>
              15  Doofus Rick <doofusrick@users.noreply.github.com>
              15  Cop Rick <yourcop@mac-mp-and.local>
              12  Snowball <snowball@artkay.nyc>
              12  Cop Morty <notyourcop@sina.cn>
              12  Weird Rick <nakedman@gmail.com>
              11  Mr. Nimbus <mr.nimbus@gmail.com>
            """
        }
        
        guard let gitCacheDirectoryPath = Current.fileManager.cacheDirectoryPath(for: pkg) else {
            throw AppError.invalidPackageCachePath(pkg.id, pkg.url)
        }
        
        // MUT
        let pkgAuthors = try PackageContributorService.authorExtractor(cacheDirPath: gitCacheDirectoryPath, packageID: pkg.id)
        
        XCTAssertEqual(pkgAuthors.authorsName, ["Rick Sanchez",
                                                "Morty Smith",
                                                "Summer Smith",
                                                "Beth Smith",
                                                "Summer"])
        XCTAssertEqual(pkgAuthors.numberOfContributors, 19)
        
    }
    
    
    

    
}
