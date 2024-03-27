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

import XCTest

@testable import App

import SemanticVersion


class ReferenceTests: XCTestCase {

    func test_init() throws {
        XCTAssertEqual(Reference("1.2.3"), .tag(1, 2, 3))
        XCTAssertEqual(Reference("1.2.3-b1"), .tag(1, 2, 3, "b1"))
        XCTAssertEqual(Reference("main"), .branch("main"))
    }

    func test_Codable() throws {
        do { // branch
            let ref = Reference.branch("foo")
            let json = try JSONEncoder().encode(ref)
            let decoded = try JSONDecoder().decode(Reference.self, from: json)
            XCTAssertEqual(decoded, .branch("foo"))
        }
        do { // tag
            let ref = Reference.tag(.init(1, 2, 3))
            let json = try JSONEncoder().encode(ref)
            let decoded = try JSONDecoder().decode(Reference.self, from: json)
            XCTAssertEqual(decoded, .tag(.init(1, 2, 3)))
        }
    }

    func test_isRelease() throws {
        XCTAssertTrue(Reference.tag(.init(1, 0, 0)).isRelease)
        XCTAssertFalse(Reference.tag(.init(1, 0, 0, "beta1")).isRelease)
        XCTAssertFalse(Reference.branch("main").isRelease)
    }

    func test_tagName() throws {
        XCTAssertEqual(Reference.tag(.init(1, 2, 3)).tagName, "1.2.3")
        XCTAssertEqual(Reference.tag(.init(1, 2, 3), "v1.2.3").tagName, "v1.2.3")
        XCTAssertEqual(Reference.tag(.init(1, 2, 3, "b1")).tagName, "1.2.3-b1")
        XCTAssertEqual(Reference.tag(.init(1, 2, 3, "b1", "test")).tagName,
                       "1.2.3-b1+test")
        XCTAssertEqual(Reference.branch("").tagName, nil)
    }

    func test_versionKind() throws {
        XCTAssertEqual(Reference.tag(.init(1, 2, 3)).versionKind, .release)
        XCTAssertEqual(Reference.tag(.init(1, 2, 3, "b1")).versionKind, .preRelease)
        XCTAssertEqual(Reference.tag(.init(1, 2, 3, "b1", "test")).versionKind, .preRelease)
        XCTAssertEqual(Reference.branch("main").versionKind, .defaultBranch)
        XCTAssertEqual(Reference.branch("").versionKind, .defaultBranch)
    }

    func test_pathEncoded() throws {
        XCTAssertEqual(Reference.branch("foo").pathEncoded, "foo")
        XCTAssertEqual(Reference.branch("foo/bar").pathEncoded, "foo-bar")
        XCTAssertEqual(Reference.branch("foo-bar").pathEncoded, "foo-bar")
        XCTAssertEqual(Reference.tag(.init("1.2.3")!).pathEncoded, "1.2.3")
        do {
            let s = try XCTUnwrap(SemanticVersion(1, 2, 3, "foo/bar"))
            XCTAssertEqual(Reference.tag(s).pathEncoded, "1.2.3-foo-bar")
        }
        do {
            let s = try XCTUnwrap(SemanticVersion(1, 2, 3, "foo/bar", "bar/baz"))
            XCTAssertEqual(Reference.tag(s).pathEncoded, "1.2.3-foo-bar+bar-baz")
        }
    }

}
