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

@testable import App

import Vapor
import XCTest


class FundingLinkTests: XCTestCase {

    func test_fundingLink_urlLabel() async throws {
        // URL with both a scheme, a host, and a subdomain.
        let ghFundingLink1 = Github.Metadata.FundingLinkNode(platform: .customUrl, url: "https://subdomain.example.com")
        let dbFundingLink1 = try XCTUnwrap(FundingLink(from: ghFundingLink1))
        XCTAssertEqual(dbFundingLink1.url, "https://subdomain.example.com")
        XCTAssertEqual(dbFundingLink1.urlLabel, "example.com")

        // URL with both a scheme and a host.
        let ghFundingLink2 = Github.Metadata.FundingLinkNode(platform: .customUrl, url: "https://example.com")
        let dbFundingLink2 = try XCTUnwrap(FundingLink(from: ghFundingLink2))
        XCTAssertEqual(dbFundingLink2.url, "https://example.com")
        XCTAssertEqual(dbFundingLink2.urlLabel, "example.com")

        // URL with a host but no scheme.
        let ghFundingLink3 = Github.Metadata.FundingLinkNode(platform: .customUrl, url: "example.com")
        let dbFundingLink3 = try XCTUnwrap(FundingLink(from: ghFundingLink3))
        XCTAssertEqual(dbFundingLink3.url, "https://example.com")
        XCTAssertEqual(dbFundingLink3.urlLabel, "example.com")

        // URL with neither.
        let ghFundingLink4 = Github.Metadata.FundingLinkNode(platform: .customUrl, url: "!@£$%")
        let dbFundingLink4 = FundingLink(from: ghFundingLink4)
        XCTAssertNil(dbFundingLink4)
    }
}
