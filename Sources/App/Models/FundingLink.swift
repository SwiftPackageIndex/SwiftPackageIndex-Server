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
        case communityBridge = "COMMUNITYBRIDGE"
        case customUrl = "CUSTOMURL"
        case gitHub = "GITHUB"
        case issueHunt = "ISSUEHUNT"
        case koFi = "KOFI"
        case lfxCrowdfunding = "LFXCROWDFUNDING"
        case liberaPay = "LIBERAPAY"
        case openCollective = "OPENCOLLECTIVE"
        case otechie = "OTECHIE"
        case patreon = "PATREON"
        case tideLift = "TIDELIFT"
    }

    var platform: Platform
    var url: String
}
