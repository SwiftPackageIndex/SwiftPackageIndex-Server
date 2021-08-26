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
            // don't show non-package results on production yet
            if Environment.current == .production && !record.isPackage {
                return nil
            }
            // -- end --
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
                    self = .package(
                        .init(packageId: record.packageId,
                              packageName: record.packageName,
                              packageURL: record.packageURL,
                              repositoryName: record.repositoryName,
                              repositoryOwner: record.repositoryOwner,
                              summary: record.summary?.replaceShorthandEmojis())
                    )
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
    }

    struct AuthorResult: Codable, Equatable {
        var name: String
    }

    struct KeywordResult: Codable, Equatable {
        var keyword: String
    }

    struct PackageResult: Codable, Equatable {
        var packageId: Package.Id?
        var packageName: String?
        var packageURL: String?
        var repositoryName: String?
        var repositoryOwner: String?
        var summary: String?
    }
}
