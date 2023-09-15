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
import JWTKit


public struct Signer {
    var signers: JWTSigners

    public init(secretSigningKey: String) {
        self.signers = {
            let s = JWTSigners()
            s.use(.hs256(key: secretSigningKey))
            return s
        }()
    }

    public func generateToken(
        for subject: String,
        expiringOn expiryDate: Date = .distantFuture,
        contact: String,
        tier: Tier<V1>
    ) throws -> String {
        let key = APIKey(sub: .init(value: subject),
                         iat: .init(value: .now),
                         exp: .init(value: expiryDate),
                         contact: contact,
                         tier: tier)
        return try signers.sign(key)
    }

    public func verifyToken(_ token: String) throws -> APIKey {
        try signers.verify(token, as: APIKey.self)
    }
}
