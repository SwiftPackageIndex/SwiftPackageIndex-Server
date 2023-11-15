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


struct FundingLink: Codable, Equatable {

    enum Platform: String, Codable {
        case communityBridge
        case customUrl
        case gitHub
        case issueHunt
        case koFi
        case lfxCrowdfunding
        case liberaPay
        case openCollective
        case otechie
        case patreon
        case tideLift

        private static let gitHubApiEncodings: [String: Platform] = [
            "COMMUNITY_BRIDGE": .communityBridge,
            "CUSTOM": .customUrl,
            "GITHUB": .gitHub,
            "ISSUEHUNT": .issueHunt,
            "KO_FI": .koFi,
            "LFX_CROWDFUNDING": .lfxCrowdfunding,
            "LIBERAPAY": .liberaPay,
            "OPEN_COLLECTIVE": .openCollective,
            "OTECHIE": .otechie,
            "PATREON": .patreon,
            "TIDELIFT": .tideLift
        ]

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let stringValue = try container.decode(String.self)

            if let value = Platform(rawValue: stringValue) {
                self = value
            } else if let value = Platform.gitHubApiEncodings[stringValue] {
                self = value
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode \(stringValue)")
            }
        }
    }

    var platform: Platform
    var url: String
}
