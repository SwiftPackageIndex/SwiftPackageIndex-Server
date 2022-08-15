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
import Vapor


/// This protocols gathers the mandatory information needed to select authors and to acknowledge contributors
protocol ContributionContext {
    /// Total number of commits
    var commits: String { get }
    var identifier : String { get }
}

public struct Contributor : ContributionContext {
    /// Total number of commits
    public let commits     : String
    public let email       : String
    public let identifier  : String
    
}

/// Version control history loader
protocol VCHistoryLoader {
    
    func loadContributorsHistory(package: Joined<Package, Repository>) throws -> [Contributor]

}

/// Loads the contributors history from a GitHub repository
struct GitHistoryLoader : VCHistoryLoader {
    
    init() {}
    
    func loadContributorsHistory(package: Joined<Package, Repository>) throws -> [Contributor] {
        do {
            let commitHistory = try queryVCHistory(package: package)
            return try parseVCHistory(log: commitHistory)
        } catch {
            throw AppError.analysisError(package.model.id, "loadContributorsHistory failed: \(error.localizedDescription)")
        }
    }
    
    /// Gets the version control history in a string log
    private func queryVCHistory(package: Joined<Package, Repository>) throws -> String {
    
        guard let cacheDir = Current.fileManager.cacheDirectoryPath(for: package.model) else {
            print("cache directory is not specified in the package model")
            throw AppError.invalidPackageCachePath(package.model.id, package.model.url)
        }
        
        if !Current.fileManager.fileExists(atPath: cacheDir) {
            do {
                try GitHistoryLoader.minClone(cacheDir: cacheDir,
                                              url: package.model.url,
                                              branch: package.repository?.defaultBranch ?? "master")
            } catch {
                throw AppError.shellCommandFailed("GitHistoryLoader.minClone",
                                                  cacheDir,
                                                  "queryVCHistory failed: \(error.localizedDescription)")
            }
        }

        // attempt to shortlog
        do {
            return try Current.shell.run(command: .gitShortlog(),
                                         at: cacheDir)
        } catch {
            throw AppError.shellCommandFailed("gitShortlog",
                                              cacheDir,
                                              "queryVCHistory failed: \(error.localizedDescription)")
        }
        
    }
    
    /// Run `git clone` without the git blobs for a given url at a given branch in a given directory.
    /// - Parameters:
    ///   - cacheDir: checkout directory
    ///   - url: url to clone from
    ///   - branch: branch name to clone from, e.g. master or main
    /// - Throws: Shell errors
    static func minClone(cacheDir: String, url: String, branch: String) throws {
        try Current.shell.run(command: .gitMinClone(url: URL(string: url)!, branch: branch, to: cacheDir),
                              at: Current.fileManager.checkoutsDirectory())
    }
    
    /// Parses the result of queryVCHistory into a collection of contributors
    public func parseVCHistory(log: String) throws -> [Contributor] {
        var committers = [Contributor]()
        
        for line in log.components(separatedBy: .newlines) {
            let log = line.split(whereSeparator: { $0 == " " || $0 == "\t"})
            
            if (log.count != 2) {
                var identifier = [String]()
                for i in 1..<(log.count - 1) {
                    identifier.append(String(log[i]))
                }
                
                let committer = Contributor(commits: String(log.first!),
                                            email: String(log.last!),
                                            identifier: identifier.joined(separator: " "))
                committers.append(committer)
            }
            
        }
        return committers
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
        if candidates.isEmpty {
            return []
        }
        
        let maxNumberOfCommits = candidates.max(by: { (a,b) -> Bool in
            return Int(a.commits)! < Int(b.commits)!
        })!.commits
        
        return candidates.filter { canditate in
            return Float(canditate.commits)! > contributorThreshold * Float(maxNumberOfCommits)!
        }
    }
    
    func selectAuthors(candidates: [Contributor]) -> [Contributor] {
        let contributors = selectContributors(candidates: candidates)
        
        if contributors.isEmpty {
            return []
        }
        
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
    
    public init(historyLoader   : VCHistoryLoader, authorSelector  : AuthorSelector) {
        self.historyLoader      = historyLoader
        self.selectionStrategy  = authorSelector
    }
    
    
    func selectAuthors(package: Joined<Package, Repository>) throws -> [Contributor] {
        let contributorsHistory = try historyLoader.loadContributorsHistory(package: package)
        return selectionStrategy.selectAuthors(candidates: contributorsHistory)
    }
    
    func selectContributors(package: Joined<Package, Repository>) throws -> [Contributor] {
        let contributorsHistory = try historyLoader.loadContributorsHistory(package: package)
        return selectionStrategy.selectContributors(candidates: contributorsHistory)
    }
    
}


private extension ShellOutCommand {
    /// Makes a minimal clone of the repository without the binary large objetcs that contain the snapshots of the files data
    static func gitMinClone(url: URL, branch: String? = "master", to path: String? = nil) -> ShellOutCommand {
        var command = "git clone \(url.absoluteString)"
        command.append(" --filter=blob:none --no-checkout --single-branch --branch")
        branch.map { command.append(argument: $0) }
        path.map { command.append(argument: $0) }

        return ShellOutCommand(string: command)
    }
    
    
    /// Gets the git commit history in a short log
    static func gitShortlog(at path: String? = nil) -> ShellOutCommand {
        var command = "git shortlog -sne"
        path.map { command.append(argument: $0) }
        return ShellOutCommand(string: command)
    }
}


// From Shellout string extension, only used here to be able to write our own ShellOutCommands
fileprivate extension String {
    var escapingSpaces: String {
        return replacingOccurrences(of: " ", with: "\\ ")
    }

    func appending(argument: String) -> String {
        return "\(self) \"\(argument)\""
    }

    func appending(arguments: [String]) -> String {
        return appending(argument: arguments.joined(separator: "\" \""))
    }

    mutating func append(argument: String) {
        self = appending(argument: argument)
    }

    mutating func append(arguments: [String]) {
        self = appending(arguments: arguments)
    }
}
