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

import Testing


extension AllTests.ViewUtilsTests {

    @Test func test_listPhrase() throws {
        // test listing 2 and 3 values
        #expect(listPhrase(nodes: ["A", "B"]).render() == "A and B")
        #expect(listPhrase(nodes: ["A", "B", "C"]).render() == "A, B, and C")
        // test opening
        #expect(listPhrase(opening: "Versions ", nodes: ["A", "B", "C"]).render() == "Versions A, B, and C")
        // test closing
        #expect(listPhrase(nodes: ["A", "B", "C"], closing: ".").render() == "A, B, and C.")
        // test empty list substitution
        #expect(listPhrase(nodes: [], ifEmpty: "none").render() == "none")
        // test conjunction
        #expect(listPhrase(nodes: ["A", "B"], conjunction: " or ").render() == "A or B")
        #expect(listPhrase(nodes: ["A", "B", "C"], conjunction: " or ").render() == "A, B, or C")
    }

    @Test func test_makeLink() async throws {
        try await withApp { app in
            // setup
            let pkg = Package(url: "1")
            try await pkg.save(on: app.db)
            let version = try Version(package: pkg)
            try await version.save(on: app.db)

            do {  // branch reference
                version.reference = .branch("main")
                #expect(
                    makeLink(packageUrl: "url", version: version) == .init(label: "main", url: "url")
                )
            }

            do {  // tag reference
                version.reference = .tag(1, 2, 3)
                #expect(
                    makeLink(packageUrl: "url", version: version) == .init(label: "1.2.3", url: "url/releases/tag/1.2.3")
                )
            }
        }
    }

}
