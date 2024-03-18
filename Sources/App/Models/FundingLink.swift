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
        case buyMeACoffee
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
        case polar
        case tidelift
    }

    var platform: Platform
    var url: String
}


extension FundingLink {
    init?(from node: Github.Metadata.FundingLinkNode) {
        platform = .init(from: node.platform)

        // Some URLs come back from the GitHub API without a scheme. In every circumstance I have
        // observed, prepending `https://` would fix the issue. We should try that simple fix, but
        // if it's still won't parse as a URL, we should discard that funding link entirely.
        if let url = URL(string: node.url), url.scheme != nil, url.host != nil {
            self.url = url.absoluteString
        } else if let url = URL(string: "https://\(node.url)"), url.host != nil {
            self.url = url.absoluteString
        } else {
            return nil
        }
    }
}


extension FundingLink.Platform {
    init(from platform: Github.Metadata.FundingLinkNode.Platform) {
        switch platform {
            case .buyMeACoffee:
                self = .buyMeACoffee
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
            case .polar:
                self = .polar
            case .tidelift:
                self = .tidelift
        }
    }
}
