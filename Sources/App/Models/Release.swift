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

import Foundation


struct Release: Codable, Equatable {
    var description: String?
    var descriptionHTML: String?
    var isDraft: Bool
    var publishedAt: Date?
    var tagName: String
    var url: String
}

extension Release {
    enum Kind: String {
        case defaultBranch
        case preRelease
        case release
    }
}

extension Release {
    init(from node: Github.Metadata.ReleaseNodes.ReleaseNode) {
        description = node.description
        descriptionHTML = node.descriptionHTML
        isDraft = node.isDraft
        publishedAt = node.publishedAt
        tagName = node.tagName
        url = node.url
    }
}
