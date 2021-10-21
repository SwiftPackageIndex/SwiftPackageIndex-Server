// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import XCTest


class ViewUtilsTests: XCTestCase {
    
    func test_pluralizedCount() throws {
        XCTAssertEqual(pluralizedCount(0, singular: "executable"), "no executables")
        XCTAssertEqual(pluralizedCount(1, singular: "executable"), "1 executable")
        XCTAssertEqual(pluralizedCount(2, singular: "executable"), "2 executables")

        XCTAssertEqual(pluralizedCount(1, singular: "library", plural: "libraries"), "1 library")
        XCTAssertEqual(pluralizedCount(2, singular: "library", plural: "libraries"), "2 libraries")
        XCTAssertEqual(pluralizedCount(0, singular: "executable"), "no executables")

        XCTAssertEqual(pluralizedCount(0, singular: "executable", capitalized: true), "No executables")
        XCTAssertEqual(pluralizedCount(0, singular: "library", plural: "libraries", capitalized: true), "No libraries")
    }
    
    func test_pluralised() throws {
        XCTAssertEqual("version".pluralized(for: 0), "versions")
        XCTAssertEqual("version".pluralized(for: 1), "version")
        XCTAssertEqual("version".pluralized(for: 2), "versions")

        XCTAssertEqual("library".pluralized(for: 0, plural: "libraries"), "libraries")
        XCTAssertEqual("library".pluralized(for: 1, plural: "libraries"), "library")
        XCTAssertEqual("library".pluralized(for: 2, plural: "libraries"), "libraries")
    }

    func test_listPhrase() throws {
        // test listing 2 and 3 values
        XCTAssertEqual(listPhrase(nodes: ["A", "B"]).render(),
                       "A and B")
        XCTAssertEqual(listPhrase(nodes: ["A", "B", "C"]).render(),
                       "A, B, and C")
        // test opening
        XCTAssertEqual(listPhrase(opening: "Versions ", nodes: ["A", "B", "C"]).render(),
                       "Versions A, B, and C")
        // test closing
        XCTAssertEqual(listPhrase(nodes: ["A", "B", "C"], closing: ".").render(),
                       "A, B, and C.")
        // test empty list substitution
        XCTAssertEqual(listPhrase(nodes: [], ifEmpty: "none").render(),
                       "none")
        // test conjunction
        XCTAssertEqual(listPhrase(nodes: ["A", "B"], conjunction: " or ").render(),
                       "A or B")
        XCTAssertEqual(listPhrase(nodes: ["A", "B", "C"], conjunction: " or ").render(),
                       "A, B, or C")
    }

}


// Test that require DB access
class ViewUtilsDBTests: AppTestCase {

    func test_makeLink() throws {
        // setup
        let pkg = Package(url: "1")
        try pkg.save(on: app.db).wait()
        let version = try Version(package: pkg)
        try version.save(on: app.db).wait()

        do {  // no reference
            XCTAssertEqual(
                makeLink(packageUrl: "url", version: version),
                nil
            )
        }

        do {  // branch reference
            version.reference = .branch("main")
            XCTAssertEqual(
                makeLink(packageUrl: "url", version: version),
                .init(label: "main", url: "url")
            )
        }

        do {  // tag reference
            version.reference = .tag(1, 2, 3)
            XCTAssertEqual(
                makeLink(packageUrl: "url", version: version),
                .init(label: "1.2.3", url: "url/releases/tag/1.2.3")
            )
        }
    }

}
