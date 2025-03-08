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

import Dependencies
import SwiftSoup
import Testing
import Vapor


extension AllTests.SearchShowModelAppTests {

    @Test func SearchShow_Model_canonicalURLAllowList() async throws {
        try await withDependencies {
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                let request = Vapor.Request(application: app,
                                            url: "search?query=alamo&page=2&utm_campaign=test&utm_source=email",
                                            on: app.eventLoopGroup.next())
                let html = try await SearchController.show(req: request).render()
                let document = try SwiftSoup.parse(html)
                let linkElements = try document.select("link[rel='canonical']")
                #expect(linkElements.count == 1)

                let href = try linkElements.first()!.attr("href")
                #expect(href == "http://localhost:8080/search?query=alamo&page=2")
            }
        }
    }

}
