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

import SnapshotTesting
import SwiftSoup
import Testing


extension AllTests.PackageReadmeModelTests {

    @Test func Element_extractReadme() throws {
        let element = Element.extractReadme("""
            <div id="readme">
                <article>
                    <p>README content.</p>
                </article>
            </div>
            """)
        #expect(try element?.html() == "<p>README content.</p>")
    }

    @Test func URL_rewriteRelative() throws {
        let triple = ("owner", "repo", "main")
        #expect(URL(string: "https://example.com")?.rewriteRelative(to: triple, fileType: .raw) == nil)
        #expect(URL(string: "https://example.com/foo")?.rewriteRelative(to: triple, fileType: .raw) == nil)
        #expect(URL(string: "/foo")?.rewriteRelative(to: triple, fileType: .raw) == "https://github.com/owner/repo/raw/main/foo")
        #expect(URL(string: "/foo")?.rewriteRelative(to: triple, fileType: .blob) == "https://github.com/owner/repo/blob/main/foo")
        #expect(URL(string: "/foo/bar?query")?.rewriteRelative(to: triple, fileType: .raw) == "https://github.com/owner/repo/raw/main/foo/bar?query")
    }

    @Test func Element_rewriteRelativeImages() throws {
        // setup
        let element = Element.extractReadme("""
            <div id="readme">
                <article>
                    <p>README content.</p>
                    <img src="https://example.com/absolute/image/url.png">
                    <img src="/root/relative/image/url.png">
                    <img src="relative/image/url.png">
                    <img src="/url/with/encoded%20spaces.png">
                    <img src="/url/with/unencoded spaces.png">
                    <img>
                </article>
            </div>
            """)

        // MUT
        element?.rewriteRelativeImages(to: ("owner", "repo", "main"))

        // validate
        let html = try #require(try element?.html())
        assertSnapshot(of: html, as: .lines)
    }

    @Test func Element_rewriteRelativeLinks() throws {
        // setup
        let element = Element.extractReadme("""
            <div id="readme">
                <article>
                    <p>README content.</p>
                    <a href="https://example.com/absolute/url">Absolute link.</a>
                    <a href="/root/relative/url">Root relative link.</a>
                    <a href="relative/url">Relative link.</a>
                    <a href="/url/with/encoded%20spaces">Encoded spaces.</a>
                    <a href="/url/with/unencoded spaces">Unencoded spaces.</a>
                    <a href="#anchor">Anchor link.</a>
                    <a>Invalid link.</a>
                </article>
            </div>
            """)

        // MUT
        element?.rewriteRelativeLinks(to: ("owner", "repo", "main"))

        // validate
        let html = try #require(try element?.html())
        assertSnapshot(of: html, as: .lines)
    }

    @Test func URL_initWithPotentiallyUnencodedPath() throws {
        // Relative URLs
        #expect(try #require(URL(withPotentiallyUnencodedPath: "/root/relative/url")).absoluteString == "/root/relative/url")
        #expect(try #require(URL(withPotentiallyUnencodedPath: "relative/url")).absoluteString == "relative/url")
        #expect(try #require(URL(withPotentiallyUnencodedPath: "/encoded%20spaces")).absoluteString == "/encoded%20spaces")
        #expect(try #require(URL(withPotentiallyUnencodedPath: "/unencoded spaces")).absoluteString == "/unencoded%20spaces")
        #expect(try #require(URL(withPotentiallyUnencodedPath: "/multiple%20%7Bencoded%7D")).absoluteString == "/multiple%20%7Bencoded%7D")
        #expect(try #require(URL(withPotentiallyUnencodedPath: "/multiple {unencoded}")).absoluteString == "/multiple%20%7Bunencoded%7D")

        // Absolute URLs
        #expect(try #require(URL(withPotentiallyUnencodedPath: "https://full.host/and/path")).absoluteString == "https://full.host/and/path")
        #expect(try #require(URL(withPotentiallyUnencodedPath: "https://full.host/encoded%20spaces")).absoluteString == "https://full.host/encoded%20spaces")
        #expect(try #require(URL(withPotentiallyUnencodedPath: "https://full.host/unencoded spaces")).absoluteString == "https://full.host/unencoded%20spaces")
    }

    @Test func Element_fixInlineAnchors() throws {
        // setup
        let element = Element.extractReadme("""
            <div id="readme">
                <article>
                    <p>README content.</p>
                    <a href="https://example.com/url">Standard link.</a>
                    <a href="#anchor">Lower case anchor link.</a>
                    <a href="#Anchor">Upper case anchor link.</a>
                    <a>Invalid link.</a>
                </article>
            </div>
            """)

        // MUT
        element?.fixInlineAnchors()

        // validate
        let html = try #require(try element?.html())
        assertSnapshot(of: html, as: .lines)
    }

    @Test func Element_fixProtectedCachedImages() throws {
        // setup
        let element = Element.extractReadme("""
            <div id="readme">
                <article>
                    <p>README content.</p>
                    <img src="https://example.com/standard.png" />
                    <img src="https://camo.githubusercontent.com/0123456789" data-canonical-src="https://example.com/cached.png" />
                    <img src="https://camo.githubusercontent.com/0123456789" data-canonical-src="" />
                    <img src="https://camo.githubusercontent.com/0123456789" />
                    <img src="https://example.com/0123456789" data-canonical-src="https://example.com/cached.png" />
                    <img />
                </article>
            </div>
            """)

        // MUT
        element?.fixProtectedCachedImages()

        // validate
        let html = try #require(try element?.html())
        assertSnapshot(of: html, as: .lines)
    }

    @Test func Element_disableTurboOnLinks() throws {
        // setup
        let element = Element.extractReadme("""
            <div id="readme">
                <article>
                    <p>README content.</p>
                    <a href="https://example.com/url">Absolute link.</a>
                    <a href="/url">Relative link.</a>
                    <a href="#anchor">Lower case anchor link.</a>
                    <a>Invalid link.</a>
                </article>
            </div>
            """)

        // MUT
        element?.disableTurboOnLinks()

        // validate
        let html = try #require(try element?.html())
        assertSnapshot(of: html, as: .lines)
    }
}
