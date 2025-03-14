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

@testable import App

import Dependencies
import Testing


extension AllTests.PlausibleTests {

    @Test func User_identifier() throws {
        #expect(User.api(for: "token") == .init(name: "api", identifier: "3c469e9d"))
    }

    @Test func props() throws {
        #expect(Plausible.props(for: nil) == ["user": "none"])
        #expect(Plausible.props(for: .init(name: "api", identifier: "foo")) == ["user": "foo"])
    }

    @Test func postEvent_anonymous() async throws {
        let called = ActorIsolated(false)
        try await withDependencies {
            $0.environment.plausibleBackendReportingSiteID = { "foo.bar" }
            $0.httpClient.post = { @Sendable _, _, body in
                await called.withValue { $0 = true }
                // validate
                let body = try #require(body)
                #expect(try JSONDecoder().decode(Plausible.Event.self, from: body)
                        == .init(name: .pageview,
                                 url: "https://foo.bar/api/search",
                                 domain: "foo.bar",
                                 props: ["user": "none"]))
                return .ok
            }
        } operation: {
            // MUT
            _ = try await Plausible.postEvent(kind: .pageview, path: .search, user: nil)

            await called.withValue { #expect($0) }
        }
    }

    @Test func postEvent_package() async throws {
        let called = ActorIsolated(false)
        try await withDependencies {
            $0.environment.plausibleBackendReportingSiteID = { "foo.bar" }
            $0.httpClient.post = { @Sendable _, _, body in
                await called.withValue { $0 = true }
                // validate
                let body = try #require(body)
                #expect(try JSONDecoder().decode(Plausible.Event.self, from: body)
                        == .init(name: .pageview,
                                 url: "https://foo.bar/api/packages/{owner}/{repository}",
                                 domain: "foo.bar",
                                 props: ["user": "3c469e9d"]))
                return .ok
            }
        } operation: {
            let user = User(name: "api", identifier: "3c469e9d")

            // MUT
            _ = try await Plausible.postEvent(kind: .pageview, path: .package, user: user)

            await called.withValue { #expect($0) }
        }
    }
}
