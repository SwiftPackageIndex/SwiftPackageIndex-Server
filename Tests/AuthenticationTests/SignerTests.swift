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


@Suite struct SignerTests {

    @Test func generateToken_verifyToken() throws {
        // Round trip test
        let s = Signer(secretSigningKey: "secret")
        let token = try s.generateToken(for: "foo", contact: "bar", tier: .tier1)
        #expect(!token.isEmpty)
        let key = try s.verifyToken(token)
        #expect(key.sub == .init(value: "foo"))
        #expect(key.contact == "bar")
        #expect(key.tier == .tier1)
    }

    @Test func verifyToken_failure() throws {
        // Ensure verification requires the correct secret
        let token = try Signer(secretSigningKey: "secret").generateToken(for: "foo", contact: "bar", tier: .tier1)
        let otherSigner = Signer(secretSigningKey: "other")
        do {
            _ = try otherSigner.verifyToken(token)
            Issue.record("Expected a JWTError.signatureVerifictionFailed to the thrown")
        } catch JWTError.signatureVerifictionFailed { }
    }

}
