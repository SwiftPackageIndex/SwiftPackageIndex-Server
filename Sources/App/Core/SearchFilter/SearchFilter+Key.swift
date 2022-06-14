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

import SQLKit

extension SearchFilter {
    enum Key: String, Codable, CaseIterable {
        // NB: these are the user-facing keys users provide in the search term,
        // e.g.: last_commit:>2020-07-01
        case author
        case keyword
        case lastActivity = "last_activity"
        case lastCommit = "last_commit"
        case license
        case platform
        case stars
        case productType = "type"

        var searchFilter: SearchFilterProtocol.Type {
            switch self {
                case .author:
                    return AuthorSearchFilter.self
                case .keyword:
                    return KeywordSearchFilter.self
                case .lastActivity:
                    return LastActivitySearchFilter.self
                case .lastCommit:
                    return LastCommitSearchFilter.self
                case .license:
                    return LicenseSearchFilter.self
                case .platform:
                    return PlatformSearchFilter.self
                case .stars:
                    return StarsSearchFilter.self
                case .productType:
                    return ProductTypeSearchFilter.self
            }
        }

        var sqlIdentifier: SQLIdentifier {
            switch self {
                case .author:
                    return SQLIdentifier("repo_owner")
                case .keyword:
                    return SQLIdentifier("keyword")
                case .lastActivity:
                    return SQLIdentifier("last_activity_at")
                case .lastCommit:
                    return SQLIdentifier("last_commit_date")
                case .license:
                    return SQLIdentifier("license")
                case .platform:
                    return SQLIdentifier("platform_compatibility")
                case .stars:
                    return SQLIdentifier("stars")
                case .productType:
                    return SQLIdentifier("type")
            }
        }
    }
}


extension SearchFilter.Key: CustomStringConvertible {
    var description: String {
        switch self {
            case .author, .license, .stars:
                return rawValue
            case .keyword:
                return "keywords"
            case .lastActivity:
                return "last activity"
            case .lastCommit:
                return "last commit"
            case .platform:
                return "platform compatibility"
            case .productType:
                return "type"
        }
    }
}
