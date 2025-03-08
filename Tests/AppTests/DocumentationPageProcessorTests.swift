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
import InlineSnapshotTesting
import SwiftSoup
import Testing


extension AllTests.DocumentationPageProcessorTests {

    @Test func header_linkTitle() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2249
        try withDependencies {
            $0.timeZone = .utc
        } operation: {
            // setup
            let coreArchive = DocArchive(name: "tecocore", title: "TecoCore")
            let signerArchive = DocArchive(name: "tecosigner", title: "Teco Signer")
            let archives: [DocumentationPageProcessor.AvailableArchive] = [
                .init(archive: coreArchive, isCurrent: false),
                .init(archive: signerArchive, isCurrent: true)
            ]
            let processor = try #require(
                DocumentationPageProcessor(
                    repositoryOwner: "owner",
                    repositoryOwnerName: "Owner Name",
                    repositoryName: "repo",
                    packageName: "package",
                    docVersion: .reference("main"),
                    referenceLatest: .release,
                    referenceKind: .release,
                    canonicalUrl: "https://example.com/owner/repo/canonical-ref",
                    availableArchives: archives,
                    availableVersions: [
                        .init(
                            kind: .defaultBranch,
                            reference: "main",
                            docArchives: [coreArchive, signerArchive],
                            isLatestStable: false
                        )
                    ],
                    updatedAt: .t0,
                    rawHtml: try fixtureString(for: "docc-template.html")
                )
            )

            // MUT & validate
            assertSnapshot(of: processor.header, as: .html)
        }
    }

    @Test func rewriteBaseUrls() throws {
        // Test rewriting of a `baseURL = "/"` (dynamic hosting) index.html
        let html = try fixtureString(for: "doc-index-dynamic-hosting.html")
        do {
            let doc = try SwiftSoup.parse(html)
            // MUT
            try DocumentationPageProcessor.rewriteBaseUrls(document: doc, owner: "foo", repository: "bar", docVersion: .reference("1.2.3"))
            // validate
            assertSnapshot(of: "\(doc)", as: .html, named: "1.2.3")
        }
        do {
            let doc = try SwiftSoup.parse(html)
            // MUT
            // The `referencing` parameter is irrelevant if the html is generated for dynamic hosting (baseUrl = "/")
            try DocumentationPageProcessor.rewriteBaseUrls(document: doc, owner: "foo", repository: "bar", docVersion: .current(referencing: "irrelevant"))
            // validate
            assertSnapshot(of: "\(doc)", as: .html, named: "current")
        }
    }

    @Test func rewriteScriptBaseUrl() throws {
        do {  // test rewriting of "/" base url
            let doc = try SwiftSoup.parse(#"""
                <script>var baseUrl = "/"</script>
                """#)
            try DocumentationPageProcessor.rewriteScriptBaseUrl(document: doc, owner: "foo", repository: "bar", docVersion: .reference("1.2.3"))
            assertInlineSnapshot(of: "\(doc)", as: .html) {
            """
            <html>
             <head>
              <script>var baseUrl = "/foo/bar/1.2.3/"</script>
             </head>
             <body></body>
            </html>
            """
            }
        }
        do {  // don't rewrite a base url that isn't "/"
            let doc = try SwiftSoup.parse(#"""
                <script>var baseUrl = "/other/"</script>
                """#)
            try DocumentationPageProcessor.rewriteScriptBaseUrl(document: doc, owner: "foo", repository: "bar", docVersion: .reference("1.2.3"))
            assertInlineSnapshot(of: "\(doc)", as: .html) {
            """
            <html>
             <head>
              <script>var baseUrl = "/other/"</script>
             </head>
             <body></body>
            </html>
            """
            }
        }
    }

    @Test func rewriteScriptBaseUrl_whiteSpace() throws {
        // test rewriting of "/" base url with whitespace
        do {
            let doc = try SwiftSoup.parse(#"""
                <script> var baseUrl = "/" </script>
                """#)
            try DocumentationPageProcessor.rewriteScriptBaseUrl(document: doc, owner: "foo", repository: "bar", docVersion: .reference("1.2.3"))
            assertInlineSnapshot(of: "\(doc)", as: .html) {
            """
            <html>
             <head>
              <script>var baseUrl = "/foo/bar/1.2.3/"</script>
             </head>
             <body></body>
            </html>
            """
            }
        }
        do {
            let doc = try SwiftSoup.parse(#"""
                <script> var baseUrl = "/" </script>
                """#)
            // The `fromReference` is irrelevant if the html is generated for dynamic hosting (baseUrl = "/")
            try DocumentationPageProcessor.rewriteScriptBaseUrl(document: doc, owner: "foo", repository: "bar", docVersion: .current(referencing: "irrelevant"))
            assertInlineSnapshot(of: "\(doc)", as: .html) {
            """
            <html>
             <head>
              <script>var baseUrl = "/foo/bar/~/"</script>
             </head>
             <body></body>
            </html>
            """
            }
        }
        do {
            let doc = try SwiftSoup.parse(#"""
                <script>
                  var baseUrl = "/"
                </script>
                """#)
            try DocumentationPageProcessor.rewriteScriptBaseUrl(document: doc, owner: "foo", repository: "bar", docVersion: .reference("1.2.3"))
            assertInlineSnapshot(of: "\(doc)", as: .html) {
            """
            <html>
             <head>
              <script>var baseUrl = "/foo/bar/1.2.3/"</script>
             </head>
             <body></body>
            </html>
            """
            }
        }
        do {
            let doc = try SwiftSoup.parse(#"""
                <script>
                  var baseUrl = "/"
                </script>
                """#)
            // The `fromReference` is irrelevant if the html is generated for dynamic hosting (baseUrl = "/")
            try DocumentationPageProcessor.rewriteScriptBaseUrl(document: doc, owner: "foo", repository: "bar", docVersion: .current(referencing: "irrelevant"))
            assertInlineSnapshot(of: "\(doc)", as: .html) {
            """
            <html>
             <head>
              <script>var baseUrl = "/foo/bar/~/"</script>
             </head>
             <body></body>
            </html>
            """
            }
        }
    }

    @Test func rewriteAttribute_current() throws {
        do {  // test rewriting of un-prefixed src attributes
            let doc = try SwiftSoup.parse(#"""
                <script src="/js/index-1.js"></script>
                <script src="/js/index-2.js"></script>
                """#)
            // The `fromReference` is irrelevant if the html is generated for dynamic hosting (baseUrl = "/")
            try DocumentationPageProcessor.rewriteAttribute("src", document: doc, owner: "foo", repository: "bar", docVersion: .current(referencing: "irrelevant"))
            assertInlineSnapshot(of: "\(doc)", as: .html) {
                """
                <html>
                 <head>
                  <script src="/foo/bar/~/js/index-1.js"></script> 
                  <script src="/foo/bar/~/js/index-2.js"></script>
                 </head>
                 <body></body>
                </html>
                """
            }
        }
        do {  // ensure we properly prefix attributes that are already prefixed
            let doc = try SwiftSoup.parse(#"""
                <script src="/foo/bar/1.2.3/js/index-1.js"></script>
                <script src="/foo/bar/1.2.3/js/index-2.js"></script>
                """#)
            try DocumentationPageProcessor.rewriteAttribute("src", document: doc, owner: "foo", repository: "bar", docVersion: .current(referencing: "1.2.3"))
            assertInlineSnapshot(of: "\(doc)", as: .html) {
                """
                <html>
                 <head>
                  <script src="/foo/bar/~/js/index-1.js"></script> 
                  <script src="/foo/bar/~/js/index-2.js"></script>
                 </head>
                 <body></body>
                </html>
                """
            }
        }
        do {  // ensure we don't prefix attributes that are already prefixed with a different reference
            let doc = try SwiftSoup.parse(#"""
                <script src="/foo/bar/1.2.3/js/index-1.js"></script>
                <script src="/foo/bar/1.2.3/js/index-2.js"></script>
                """#)
            try DocumentationPageProcessor.rewriteAttribute("src", document: doc, owner: "foo", repository: "bar", docVersion: .current(referencing: "2.0.0"))
            assertInlineSnapshot(of: "\(doc)", as: .html) {
                """
                <html>
                 <head>
                  <script src="/foo/bar/1.2.3/js/index-1.js"></script> 
                  <script src="/foo/bar/1.2.3/js/index-2.js"></script>
                 </head>
                 <body></body>
                </html>
                """
            }
        }
    }

    @Test func rewriteAttribute_toReference() throws {
        do {  // test rewriting of un-prefixed src attributes
            let doc = try SwiftSoup.parse(#"""
                <script src="/js/index-1.js"></script>
                <script src="/js/index-2.js"></script>
                """#)
            try DocumentationPageProcessor.rewriteAttribute("src", document: doc, owner: "foo", repository: "bar", docVersion: .reference("1.2.3"))
            assertInlineSnapshot(of: "\(doc)", as: .html) {
                """
                <html>
                 <head>
                  <script src="/foo/bar/1.2.3/js/index-1.js"></script> 
                  <script src="/foo/bar/1.2.3/js/index-2.js"></script>
                 </head>
                 <body></body>
                </html>
                """
            }
        }
        do {  // ensure we don't prefix attributes that are already prefixed
            let doc = try SwiftSoup.parse(#"""
                <script src="/foo/bar/1.2.3/js/index-1.js"></script>
                <script src="/foo/bar/1.2.3/js/index-2.js"></script>
                """#)
            try DocumentationPageProcessor.rewriteAttribute("src", document: doc, owner: "foo", repository: "bar", docVersion: .reference("1.2.3"))
            assertInlineSnapshot(of: "\(doc)", as: .html) {
                """
                <html>
                 <head>
                  <script src="/foo/bar/1.2.3/js/index-1.js"></script> 
                  <script src="/foo/bar/1.2.3/js/index-2.js"></script>
                 </head>
                 <body></body>
                </html>
                """
            }
        }
        do {  // ensure we don't prefix attributes that are already prefixed for a different reference
              // (this probably cannot happen in practise but we certainly don't want to prefix in this case)
            let doc = try SwiftSoup.parse(#"""
                <script src="/foo/bar/main/js/index-1.js"></script>
                <script src="/foo/bar/main/js/index-2.js"></script>
                """#)
            try DocumentationPageProcessor.rewriteAttribute("src", document: doc, owner: "foo", repository: "bar", docVersion: .reference("1.2.3"))
            assertInlineSnapshot(of: "\(doc)", as: .html) {
                """
                <html>
                 <head>
                  <script src="/foo/bar/main/js/index-1.js"></script> 
                  <script src="/foo/bar/main/js/index-2.js"></script>
                 </head>
                 <body></body>
                </html>
                """
            }
        }
    }
}
