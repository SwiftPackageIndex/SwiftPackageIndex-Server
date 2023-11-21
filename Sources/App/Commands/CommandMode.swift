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

import Vapor


enum SPICommand {
    static let defaultLimit = 1

    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l", help: "Number of packages to import in one batch.")
        var limit: Int?

        @Option(name: "id", help: "The database ID for the package.")
        var id: Package.Id?

        @Option(name: "url", help: "Package URL or fragment. For example owner/repo.")
        var url: String?
    }

    enum Mode {
        case id(Package.Id)
        case limit(Int)
        case url(String)

        init(signature: Signature) {
            if let id = signature.id {
                self = .id(id)
            } else if let url = signature.url {
                self = .url(url)
            } else if let limit = signature.limit {
                self = .limit(limit)
            } else {
                self = .limit(SPICommand.defaultLimit)
            }
        }
    }
}
