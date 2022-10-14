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


struct PackageAuthors: Codable, Equatable {
    var authors: [Author]
    var numberOfContributors: Int
}

enum PackageContributors {

    /// Extracts the possible authors of the package according to the number of commits.
    /// A contributor is considered an author when the number of commits is at least a 60 percent
    /// of the maximum commits done by a contributor.
    /// - Parameters:
    ///   - gitCacheDirectoryPath: path to the cache directory where the clone of the package is stored
    ///   - packageID: the UUID of the package
    /// - Returns: PackageAuthors
    static func extract(gitCacheDirectoryPath: String, packageID: UUID?) throws -> PackageAuthors {
        let contributorsHistory = try GitHistoryLoader.loadContributorsHistory(gitCacheDirectoryPath: gitCacheDirectoryPath, packageID: packageID)
        let authors = primaryContributors(candidates: contributorsHistory, threshold: 0.6)

        return PackageAuthors(authors: authors.map { Author(name: $0.name) },
                              numberOfContributors: contributorsHistory.count - authors.count)
    }


    struct Contributor {
        /// Total number of commits
        let numberOfCommits: Int
        let name: String
    }

    /// Loads the contributors history from a Git repository
    struct GitHistoryLoader {

        static func loadContributorsHistory(gitCacheDirectoryPath: String, packageID: UUID?) throws -> [Contributor] {
            do {
                let commitHistory = try queryGitHistory(gitCacheDirectoryPath: gitCacheDirectoryPath, packageID: packageID)
                return try parseGitHistory(log: commitHistory)
            } catch {
                throw AppError.analysisError(packageID, "loadContributorsHistory failed: \(error.localizedDescription)")
            }
        }

        /// Gets the git history in a string log
        private static func queryGitHistory(gitCacheDirectoryPath: String, packageID: UUID?) throws -> String {

            if !Current.fileManager.fileExists(atPath: gitCacheDirectoryPath) {
                throw AppError.cacheDirectoryDoesNotExist(packageID, gitCacheDirectoryPath)
            }

            // attempt to shortlog
            do {
                return try Current.git.shortlog(gitCacheDirectoryPath)
            } catch {
                throw AppError.shellCommandFailed("gitShortlog",
                                                  gitCacheDirectoryPath,
                                                  "queryGitHistory failed: \(error.localizedDescription)")
            }
        }

        /// Parses the result of queryGitHistory into a collection of contributors
        private static func parseGitHistory(log: String) throws -> [Contributor] {
            var committers = [Contributor]()

            for line in log.components(separatedBy: .newlines) {
                let log = line.split(whereSeparator: { $0 == " " || $0 == "\t"})

                if (log.count > 2) {
                    var identifier = [String]()
                    for i in 1..<(log.count - 1) {
                        identifier.append(String(log[i]))
                    }
                    var numberOfCommits = 0
                    if (log.first != nil) {
                        numberOfCommits = Int(log.first!) ?? 0
                    }
                    let committer = Contributor(numberOfCommits: numberOfCommits,
                                                name: identifier.joined(separator: " "))
                    committers.append(committer)
                }

            }
            return committers
        }

    }

    /// Strategy for selecting contributors based entirely on the number of commits
    static func primaryContributors(candidates: [Contributor], threshold: Float) -> [Contributor] {
        if candidates.isEmpty {
            return []
        }

        let maxNumberOfCommits = candidates.max(by: { (a,b) -> Bool in
            return a.numberOfCommits < b.numberOfCommits
        })!.numberOfCommits

        return candidates.filter { canditate in
            return Float(canditate.numberOfCommits) > threshold * Float(maxNumberOfCommits)
        }
    }





}








