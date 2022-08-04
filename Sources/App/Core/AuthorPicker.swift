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



/// This protocols gathers the mandatory information needed to select authors and to identify endorsed contributors
protocol ContributionContext {
    /// Total number of commits
    var commits: String { get }
    var identifier : String { get }
}

/// Version Control history loader
protocol VCHistoryLoader {
    associatedtype Contributor : ContributionContext
    
    /// Gets the version control history in a string log
    func queryVCHistory(repositoryURL: String) -> String?
    
    /// Parses the result of queryVCHistory
    func parseVCHistory(log: String) -> [Contributor]
}

public struct Contributor : ContributionContext {
    /// Total number of commits
    public let commits     : String
    public let firstName   : String
    public let lastName    : String
    public let email       : String
    public let identifier  : String
    
}


public struct GitHubHistoryLoader : VCHistoryLoader {
    
    public init() {}
    
    // TODO: Make better error handling
    public func queryVCHistory(repositoryURL : String) -> String? {
        do {
            try makeMinimalClone(repositoryURL : repositoryURL)
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
    private func makeMinimalClone(repositoryURL : String) throws {
        
        let repositoryName = extractPackageName(repositoryURL: repositoryURL)
        
        let folderName = repositoryName + "Clone"
        try self.makeFolder(named: folderName)
        
        // TODO: branch could have different names: master or main. Update: we have that info!
        try shellOut(to: "git clone --filter=blob:none --no-checkout --single-branch --branch master",
                     arguments: [repositoryURL, "."],
                     at: folderName)
        
//        try shellOut(to: "git clone --filter=blob:none --no-checkout --single-branch --branch main",
//                     arguments: [repositoryURL, "."],
//                     at: folderName)

    }
    
    
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
            } else {
                let committer = Contributor(commits: String(log[0]),
                                             firstName: String(log[1]),
                                             lastName: "",
                                             email: String(log[2]),
                                             identifier: String(log[1]))
                committers.append(committer)
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


protocol AuthorSelector {
    associatedtype Contributor : ContributionContext
    
    func selectAuthors(candidates : [Contributor] ) -> [Contributor]
    
    func selectContributors(candidates : [Contributor] ) -> [Contributor]
}


public struct SelectorManager : AuthorSelector {
    
    let contributorThreshold : Float
    let authorThreshold      : Float
    
    public init(contributorThreshold: Float, authorThreshold : Float) {
        self.contributorThreshold   = contributorThreshold
        self.authorThreshold        = authorThreshold
    }
    
    public func selectContributors(candidates: [Contributor]) -> [Contributor] {
        let maxNumberOfCommits = candidates.max(by: { (a,b) -> Bool in
            return Int(a.commits)! < Int(b.commits)!
        })!.commits
        
        return candidates.filter { canditate in
            return Float(canditate.commits)! > contributorThreshold * Float(maxNumberOfCommits)!
        }
    }
    
    public func selectAuthors(candidates: [Contributor]) -> [Contributor] {
        let contributors = selectContributors(candidates: candidates)
        
        let maxNumberOfCommits = contributors.max(by: { (a,b) -> Bool in
            return Int(a.commits)! < Int(b.commits)!
        })!.commits
        
        return candidates.filter { canditate in
            return Float(canditate.commits)! > authorThreshold * Float(maxNumberOfCommits)!
        }
    }
    
}




final class GitHubAuthorPicker {
    private let historyLoader   : GitHubHistoryLoader
    private let authorSelector  : SelectorManager

    public init(authorThreshold: Float, contributorThreshold: Float = 0.02) {
        self.historyLoader      = GitHubHistoryLoader()
        self.authorSelector     = SelectorManager(contributorThreshold: contributorThreshold,
                                                  authorThreshold: authorThreshold)
    }

    public func pickAuthors(repositoryURL: String, authorThreshold: Float = 0.6) -> [Contributor] {
        guard let logHistory = historyLoader.queryVCHistory(repositoryURL: repositoryURL)
        else {
            fatalError("history could not be loaded")
        }
        let committers = historyLoader.parseVCHistory(log: logHistory)
        let authors = authorSelector.selectAuthors(candidates: committers)
        return authors
    }
}


