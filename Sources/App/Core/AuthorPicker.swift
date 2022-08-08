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

import Foundation
import ShellOut



/// This protocols gathers the mandatory information needed to select authors and to acknowledge contributors
protocol ContributionContext {
    /// Total number of commits
    var commits: String { get }
    var identifier : String { get }
}

public struct Contributor : ContributionContext {
    /// Total number of commits
    public let commits     : String
    public let firstName   : String
    public let lastName    : String
    public let email       : String
    public let identifier  : String
    
}

/// Version control history loader
protocol VCHistoryLoader {
    
    func loadContributorsHistory(repositoryURL: String, defaultBranch: String) -> [Contributor]

}

/// Loads the contributors history from a GitHub repository
struct GitHubHistoryLoader : VCHistoryLoader {
    
    init() {}
    
    func loadContributorsHistory(repositoryURL: String, defaultBranch: String) -> [Contributor] {
        guard let commitHistory = queryVCHistory(repositoryURL: repositoryURL, defaultBranch: defaultBranch)
        else{
            return []
        }
        return parseVCHistory(log: commitHistory)
    }
    
    // TODO: Make better error handling
    /// Gets the version control history in a string log
    private func queryVCHistory(repositoryURL : String, defaultBranch: String) -> String? {
        do {
            try makeMinimalClone(repositoryURL : repositoryURL, defaultBranch: defaultBranch)
        } catch {
            let error = error as! ShellOutError
            print(error.message) // Prints STDERR
            print(error.output) // Prints STDOUT
        }
        let repositoryName = extractPackageName(repositoryURL: repositoryURL)
        let shortlog = try? gitShortlog(repositoryName: repositoryName)
        return shortlog
    }
    
    
    /// Makes a minimal clone of the repository without the binary large objetcs that contain the snapshots of the files data
    private func makeMinimalClone(repositoryURL : String, defaultBranch: String) throws {
        
        let repositoryName = extractPackageName(repositoryURL: repositoryURL)
        
        let folderName = repositoryName + "Clone"
        try self.makeFolder(named: folderName)
        
        try shellOut(to: "git clone --filter=blob:none --no-checkout --single-branch --branch",
                     arguments: [defaultBranch, repositoryURL, "."],
                     at: folderName)
    }
    
    /// Parses the result of queryVCHistory
    private func gitShortlog(repositoryName: String) throws -> String {
        let folderName = repositoryName + "Clone"
        let shortlog = try shellOut(to: "git shortlog -sne", at: folderName)
        return shortlog
    }
    
    /// Makes a new folder with the given name.
    /// If the folder already exists it will override it
    private func makeFolder(named: String) throws {
        guard let _ = try? shellOut(to: .createFolder(named: named))
        else {
            try shellOut(to: "rm -rf", arguments: [named])
            try shellOut(to: .createFolder(named: named))
            return
        }
    }
    
    public func parseVCHistory(log: String) -> [Contributor] {
        var committers = [Contributor]()
        
        for line in log.components(separatedBy: .newlines) {
            let log = line.split(whereSeparator: { $0 == " " || $0 == "\t"})
            // TODO: find which information is mandatory in the log commits. Apparently last name is not mandatory
            if log.count == 4 {
                let committer = Contributor(commits: String(log[0]),
                                             firstName: String(log[1]),
                                             lastName: String(log[2]),
                                             email: String(log[3]),
                                             identifier: String(log[1]) + " " + String(log[2]))
                committers.append(committer)
            } else if log.count == 3 {
                let committer = Contributor(commits: String(log[0]),
                                             firstName: String(log[1]),
                                             lastName: "",
                                             email: String(log[2]),
                                             identifier: String(log[1]))
                committers.append(committer)
            } else {
                // TODO: Handle error
            }

        }
        return committers
    }
    
    private func extractPackageName(repositoryURL: String) -> String {
        guard var start = repositoryURL.lastIndex(of: "/"),
              let end = repositoryURL.lastIndex(of: ".")
        else {
            fatalError("not a valid repository URL: \(repositoryURL)")
        }
        start = repositoryURL.index(after: start)
        return String(repositoryURL[start..<end])
    }
}

/// Protocol for all author selection strategies
protocol AuthorSelector {
    
    func selectAuthors(candidates : [Contributor] ) -> [Contributor]
    
    func selectContributors(candidates : [Contributor] ) -> [Contributor]
    
}

/// Strategy for selecting authors based entirely on the number of commits
struct CommitSelector : AuthorSelector {
    
    let contributorThreshold    : Float
    let authorThreshold         : Float
    
    
    init(contributorThreshold: Float = 0.02, authorThreshold : Float = 0.6) {
        self.contributorThreshold   = contributorThreshold
        self.authorThreshold        = authorThreshold
    }
    
    func selectContributors(candidates: [Contributor]) -> [Contributor] {
        let maxNumberOfCommits = candidates.max(by: { (a,b) -> Bool in
            return Int(a.commits)! < Int(b.commits)!
        })!.commits
        
        return candidates.filter { canditate in
            return Float(canditate.commits)! > contributorThreshold * Float(maxNumberOfCommits)!
        }
    }
    
    func selectAuthors(candidates: [Contributor]) -> [Contributor] {
        let contributors = selectContributors(candidates: candidates)
        
        let maxNumberOfCommits = contributors.max(by: { (a,b) -> Bool in
            return Int(a.commits)! < Int(b.commits)!
        })!.commits
        
        return candidates.filter { canditate in
            return Float(canditate.commits)! > authorThreshold * Float(maxNumberOfCommits)!
        }
    }
    
}




final class AuthorPickerService {
    /// loads the list of contributors with its history
    private let historyLoader       : VCHistoryLoader
    /// strategy for picking the author and acknowledged contributors
    private let selectionStrategy   : AuthorSelector
    private let repositoryURL       : String
    private let defaultBranch       : String
    
    public init(historyLoader   : VCHistoryLoader, authorSelector  : AuthorSelector, repositoryURL: String, defaultBranch: String) {
        self.historyLoader      = historyLoader
        self.selectionStrategy  = authorSelector
        self.repositoryURL      = repositoryURL
        self.defaultBranch      = defaultBranch
    }
    
    func selectAuthors() -> [Contributor] {
        let contributorsHistory = historyLoader.loadContributorsHistory(repositoryURL: repositoryURL, defaultBranch: defaultBranch)
        return selectionStrategy.selectAuthors(candidates: contributorsHistory)
    }
    
    func selectContributors() -> [Contributor] {
        let contributorsHistory = historyLoader.loadContributorsHistory(repositoryURL: repositoryURL, defaultBranch: defaultBranch)
        return selectionStrategy.selectContributors(candidates: contributorsHistory)
    }
    
}
