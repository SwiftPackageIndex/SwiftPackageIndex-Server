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
        case liberapay
        case openCollective
        case otechie
        case patreon
        case tidelift
    }

    var platform: Platform
    var url: String
}


extension FundingLink {
    init(from node: Github.Metadata.FundingLinkNode) {
        platform = .init(from: node.platform)
        url = node.url
    }
}


extension FundingLink.Platform {
    init(from platform: Github.Metadata.FundingLinkNode.Platform) {
        switch platform {
            case .communityBridge:
                self = .communityBridge
            case .customUrl:
                self = .customUrl
            case .gitHub:
                self = .gitHub
            case .issueHunt:
                self = .issueHunt
            case .koFi:
                self = .koFi
            case .lfxCrowdfunding:
                self = .lfxCrowdfunding
            case .liberapay:
                self = .liberapay
            case .openCollective:
                self = .openCollective
            case .otechie:
                self = .otechie
            case .patreon:
                self = .patreon
            case .tidelift:
                self = .tidelift
        }
    }
}
