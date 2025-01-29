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

import Dependencies
import ShellOut
import Vapor


struct PackageAuthors: Codable, Equatable {
    var authors: [Author]
    var numberOfContributors: Int

    var hasAuthors: Bool {
        // No need to check numberOfContributors here. If there are no authors, there are no authors.
        authors.isEmpty == false
    }
}

enum PackageContributors {

    /// Extracts the possible authors of the package according to the number of commits.
    /// A contributor is considered an author when the number of commits is at least a 60 percent
    /// of the maximum commits done by a contributor.
    /// - Parameters:
    ///   - gitCacheDirectoryPath: path to the cache directory where the clone of the package is stored
    ///   - packageID: the UUID of the package
    /// - Returns: PackageAuthors
    static func extract(gitCacheDirectoryPath: String, packageID: UUID?) async throws -> PackageAuthors {
        let contributorsHistory = try await GitShortlog.loadContributors(gitCacheDirectoryPath: gitCacheDirectoryPath, packageID: packageID)
        let authors = primaryContributors(candidates: contributorsHistory, threshold: 0.6)

        return PackageAuthors(authors: authors.map { Author(name: $0.name) },
                              numberOfContributors: contributorsHistory.count - authors.count)
    }


    struct Contributor {
        /// Total number of commits
        let numberOfCommits: Int
        let name: String
    }

    /// Loads git contributors from repository history
    private struct GitShortlog {

        static func loadContributors(gitCacheDirectoryPath: String, packageID: UUID?) async throws -> [Contributor] {
            do {
                let commitHistory = try await runShortlog(gitCacheDirectoryPath: gitCacheDirectoryPath, packageID: packageID)
                return try parse(logHistory: commitHistory)
            } catch {
                throw AppError.analysisError(packageID, "loadContributorsHistory failed: \(error.localizedDescription)")
            }
        }

        /// Gets the git history in a string log
        private static func runShortlog(gitCacheDirectoryPath: String, packageID: UUID?) async throws -> String {
            @Dependency(\.fileManager) var fileManager
            @Dependency(\.git) var git

            if fileManager.fileExists(atPath: gitCacheDirectoryPath) == false {
                throw AppError.cacheDirectoryDoesNotExist(packageID, gitCacheDirectoryPath)
            }

            // attempt to shortlog
            do {
                return try await git.shortlog(gitCacheDirectoryPath)
            } catch {
                throw AppError.shellCommandFailed("gitShortlog",
                                                  gitCacheDirectoryPath,
                                                  "queryGitHistory failed: \(error.localizedDescription)")
            }
        }

        /// Parses the string result of queryGitHistory into a collection of contributors
        /// The assumption here is that each log is of the form `numberOfCommits\tName`
        /// where the numberOfCommits can have leading white spaces.
        /// It is assumed that order. Example:
        /// ` 1000\tJohn Albert Doe`
        /// This method only parses the number of commits and the name of the commiter
        private static func parse(logHistory: String) throws -> [Contributor] {
            var committers = [Contributor]()

            for line in logHistory.components(separatedBy: .newlines) {
                let log = line.split(whereSeparator: {$0 == "\t"})
                if (log.count == 2) {
                    let numberOfCommits = Int(log[0].trimmingCharacters(in: .whitespaces)) ?? 0
                    let identifier = String(log[1])
                    committers.append(Contributor(numberOfCommits: numberOfCommits,
                                                  name: identifier))
                }
            }
            return committers
        }
    }

    /// Strategy for selecting contributors based entirely on the number of commits.
    /// The main contributor is automatically a primary contributor and the rest are
    /// considered primary contributors if their number of commits is above
    /// a percentage of the main contributors commit
    /// - Parameters:
    ///   - candidates: collection of all the contributors
    ///   - threshold: percentage of the highest number of commits to be taken as a threshold
    /// - Returns: collection of primary contributors `[Contributor]`
    static func primaryContributors(candidates: [Contributor], threshold: Float) -> [Contributor] {
        if candidates.isEmpty {
            return []
        }

        guard let mainContributor = candidates.max(by: { (a,b) -> Bool in
            return a.numberOfCommits < b.numberOfCommits
        }) else {
            return []
        }

        return candidates.filter { canditate in
            return Float(canditate.numberOfCommits) > threshold * Float(mainContributor.numberOfCommits)
        }
    }

}
