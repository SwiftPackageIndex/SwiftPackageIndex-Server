// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Vapor


extension Search {
    enum Result: Codable, Equatable {
        case author(AuthorResult)
        case keyword(KeywordResult)
        case package(PackageResult)

        init?(_ record: DBRecord) {
            switch (record.matchType, record.repositoryOwner, record.keyword) {
                case let (.author, .some(repoOwner), _):
                    self = .author(.init(name: repoOwner))
                case (.author, _, _):
                    return nil
                case let (.keyword, _, .some(kw)):
                    self = .keyword(.init(keyword: kw))
                case (.keyword, _, _):
                    return nil
                case (.package, _, _):
                    guard let result = PackageResult(packageId: record.packageId,
                                                     packageName: record.packageName,
                                                     packageURL: record.packageURL,
                                                     repositoryName: record.repositoryName,
                                                     repositoryOwner: record.repositoryOwner,
                                                     stars: record.stars,
                                                     lastActivityAt: record.lastActivityAt,
                                                     summary: record.summary?.replaceShorthandEmojis(),
                                                     keywords: nil) // TODO: Pull the keywords through in the search query.
                    else { return nil }
                    self = .package(result)
            }
        }

        var isPackage: Bool {
            switch self {
                case .author, .keyword:
                    return false
                case .package:
                    return true
            }
        }

        var authorResult: AuthorResult? {
            switch self {
                case let .author(result):
                    return result
                case .keyword, .package:
                    return nil
            }
        }

        var keywordResult: KeywordResult? {
            switch self {
                case let .keyword(result):
                    return result
                case .author, .package:
                    return nil
            }
        }

        var packageResult: PackageResult? {
            switch self {
                case let .package(result):
                    return result
                case .author, .keyword:
                    return nil
            }
        }
    }

    struct AuthorResult: Codable, Equatable {
        var name: String
    }

    struct KeywordResult: Codable, Equatable {
        var keyword: String
    }

    struct PackageResult: Codable, Equatable {
        var packageId: Package.Id
        var packageName: String?
        var packageURL: String
        var repositoryName: String
        var repositoryOwner: String
        var stars: Int?
        var lastActivityAt: Date?
        var summary: String?
        var keywords: [String]?

        init?(packageId: Package.Id?,
              packageName: String?,
              packageURL: String?,
              repositoryName: String?,
              repositoryOwner: String?,
              stars: Int?,
              lastActivityAt: Date?,
              summary: String?,
              keywords: [String]?) {
            guard let packageId = packageId,
                  let packageURL = packageURL,
                  let repositoryName = repositoryName,
                  let repositoryOwner = repositoryOwner
            else { return nil }

            self.packageId = packageId
            self.packageName = packageName
            self.packageURL = packageURL
            self.repositoryName = repositoryName
            self.repositoryOwner = repositoryOwner
            self.stars = stars
            self.lastActivityAt = lastActivityAt
            self.summary = summary
            self.keywords = keywords
        }
    }
}
