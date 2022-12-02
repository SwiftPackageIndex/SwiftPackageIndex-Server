// Copyright 2020-2022 Dave Verwer, Sven A. Schmidt, and other contributors.
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


enum Mastodon {

    private static let apiUrl: String = "https://api.twitter.com/1.1/statuses/update.json"
    private static let postMaxLength = 490  // 500, leaving some buffer for unicode accounting oddities

    enum Error: LocalizedError {
        case invalidMessage
        case missingCredentials
        case requestFailed(HTTPStatus, String)
    }

    struct Credentials {
        var clientKey: String
        var clientSecret: String
        var accessToken: String
    }

    static func post(client: Client, message: String) async throws {
    }

}


