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

import SemanticVersion
import Testing


extension AllTests.ReferenceTests {

    @Test func Refernce_init() throws {
        #expect(Reference("1.2.3") == .tag(1, 2, 3))
        #expect(Reference("1.2.3-b1") == .tag(1, 2, 3, "b1"))
        #expect(Reference("main") == .branch("main"))
    }

    @Test func Codable() throws {
        do { // branch
            let ref = Reference.branch("foo")
            let json = try JSONEncoder().encode(ref)
            let decoded = try JSONDecoder().decode(Reference.self, from: json)
            #expect(decoded == .branch("foo"))
        }
        do { // tag
            let ref = Reference.tag(.init(1, 2, 3))
            let json = try JSONEncoder().encode(ref)
            let decoded = try JSONDecoder().decode(Reference.self, from: json)
            #expect(decoded == .tag(.init(1, 2, 3)))
        }
    }

    @Test func isRelease() throws {
        #expect(Reference.tag(.init(1, 0, 0)).isRelease)
        #expect(!Reference.tag(.init(1, 0, 0, "beta1")).isRelease)
        #expect(!Reference.branch("main").isRelease)
    }

    @Test func tagName() throws {
        #expect(Reference.tag(.init(1, 2, 3)).tagName == "1.2.3")
        #expect(Reference.tag(.init(1, 2, 3), "v1.2.3").tagName == "v1.2.3")
        #expect(Reference.tag(.init(1, 2, 3, "b1")).tagName == "1.2.3-b1")
        #expect(Reference.tag(.init(1, 2, 3, "b1", "test")).tagName == "1.2.3-b1+test")
        #expect(Reference.branch("").tagName == nil)
    }

    @Test func versionKind() throws {
        #expect(Reference.tag(.init(1, 2, 3)).versionKind == .release)
        #expect(Reference.tag(.init(1, 2, 3, "b1")).versionKind == .preRelease)
        #expect(Reference.tag(.init(1, 2, 3, "b1", "test")).versionKind == .preRelease)
        #expect(Reference.branch("main").versionKind == .defaultBranch)
        #expect(Reference.branch("").versionKind == .defaultBranch)
    }

    @Test func pathEncoded() throws {
        #expect(Reference.branch("foo").pathEncoded == "foo")
        #expect(Reference.branch("foo/bar").pathEncoded == "foo-bar")
        #expect(Reference.branch("foo-bar").pathEncoded == "foo-bar")
        #expect(Reference.tag(.init("1.2.3")!).pathEncoded == "1.2.3")
        do {
            let s = SemanticVersion(1, 2, 3, "foo/bar")
            #expect(Reference.tag(s).pathEncoded == "1.2.3-foo-bar")
        }
        do {
            let s = SemanticVersion(1, 2, 3, "foo/bar", "bar/baz")
            #expect(Reference.tag(s).pathEncoded == "1.2.3-foo-bar+bar-baz")
        }
    }

}
