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

import JWTKit


public struct APIKey {
    public var sub: SubjectClaim
    public var iat: IssuedAtClaim
    public var exp: ExpirationClaim
    public var contact: String
    public var tier: Tier
}

extension APIKey {
    public func isAuthorized(for tier: Tier) -> Bool {
        self.tier >= tier
    }
}

extension APIKey: JWTPayload {
    public func verify(using signer: JWTKit.JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}
