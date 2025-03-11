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

@testable import Authentication

import JWTKit
import Testing


@Suite struct APIKeyTests {

    @Test func verify() throws {
        // Ensure verification rejects expired tokens
        let s = Signer(secretSigningKey: "secret")
        let token = try s.generateToken(for: "foo", expiringOn: .distantPast, contact: "bar", tier: .tier1)
        do {
            _ = try s.verifyToken(token)
            Issue.record("Expected a JWTError.claimVerificationFailure to the thrown")
        } catch let JWTError.claimVerificationFailure(name: name, reason: reason) {
            #expect(name == "exp")
            #expect(reason == "expired")
        }
    }

    @Test func isAuthorized() throws {
        #expect(APIKey.mock(tier: .internal).isAuthorized(for: .tier1))
        #expect(APIKey.mock(tier: .internal).isAuthorized(for: .tier2))
        #expect(APIKey.mock(tier: .tier1).isAuthorized(for: .tier1))
        #expect(!APIKey.mock(tier: .tier1).isAuthorized(for: .tier2))
    }

}


extension APIKey {
    static func mock(issuedAt: Date = .now, expiresAt: Date = .distantFuture, tier: Tier<V1>) -> Self {
        .init(sub: .init(value: ""),
              iat: .init(value: issuedAt),
              exp: .init(value: expiresAt),
              contact: "",
              tier: tier)
    }
}
