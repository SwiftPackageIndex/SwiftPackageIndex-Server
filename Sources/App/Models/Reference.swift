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
import SemanticVersion


enum Reference: Equatable, Hashable {
    case branch(String)
    case tag(SemanticVersion, _ tagName: String)

    static func tag(_ semVer: SemanticVersion) -> Self {
        .tag(semVer, "\(semVer)")
    }

    static func tag(_ major: Int, _ minor: Int, _ patch: Int, _ preRelease: String = "", _ build: String = "") -> Self {
        .tag(SemanticVersion(major, minor, patch, preRelease, build))
    }

    var isBranch: Bool {
        switch self {
            case .branch: return true
            case .tag:    return false
        }
    }

    var isTag: Bool { !isBranch }

    var semVer: SemanticVersion? {
        switch self {
            case .branch:
                return nil
            case .tag(let v, _):
                return v
        }
    }

    var isRelease: Bool { semVer?.isStable ?? false }

    var branchName: String? {
        switch self {
            case let .branch(name):
                return name
            case .tag:
                return nil
        }
    }

    var tagName: String? {
        switch self {
            case .branch:
                return nil
            case let .tag(_, tagName):
                return tagName
        }
    }

    var versionKind: Version.Kind {
        switch self {
            case .branch:
                return .defaultBranch
            case .tag(let semVer, _):
                return semVer.isPreRelease ? .preRelease : .release
        }
    }
}


extension Reference: Codable {
    private struct Tag: Codable {
        var semVer: SemanticVersion
        var tagName: String
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(String.self, forKey: .branch) {
            self = .branch(value)
            return
        }
        if let value = try? container.decode(Tag.self, forKey: .tag) {
            self = .tag(value.semVer, value.tagName)
            return
        }
        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: container.codingPath,
                                  debugDescription: "none of the required keys found"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .branch(let value):
                try container.encode(value, forKey: .branch)
            case let .tag(semVer, tagName):
                try container.encode(Tag(semVer: semVer, tagName: tagName), forKey: .tag)
        }
    }

    enum CodingKeys: CodingKey, CaseIterable {
        case branch
        case tag
    }
}


extension Reference: CustomStringConvertible {
    var description: String {
        switch self {
            case .branch(let value): return value
            case .tag(_, let value): return value
        }
    }
}
