@testable import App

import XCTVapor
import SnapshotTesting


class PackageReadmeModelTests: SnapshotTestCase {

    func test_processReadme_extractReadmeElement() throws {
        let model = PackageReadme.Model(readme: """
            <html>
                <head>
                    <title>README file</title>
                </head>
                <body>
                    <p>Other page content.</p>
                    <div id="readme">
                        <article>
                            <p>README content.</p>
                        </article>
                    </div>
                </body>
            </html>
            """)

        let readme = try XCTUnwrap(model.readme)
        assertSnapshot(matching: readme, as: .lines)
    }

    func test_processReadme_processRelativeImages() throws {
        let model = PackageReadme.Model(readme: """
            <html>
                <head>
                    <title>README file</title>
                </head>
                <body>
                    <p>Other page content.</p>
                    <div id="readme">
                        <article>
                            <p>README content.</p>
                            <img src="https://example.com/absolute/image/url.png">
                            <img src="/root/relative/image/url.png">
                            <img src="relative/image/url.png">
                            <img>
                        </article>
                    </div>
                </body>
            </html>
            """)

        let readme = try XCTUnwrap(model.readme)
        assertSnapshot(matching: readme, as: .lines)
    }

    func test_processReadme_processRelativeLinks() throws {
        let model = PackageReadme.Model(readme: """
            <html>
                <head>
                    <title>README file</title>
                </head>
                <body>
                    <p>Other page content.</p>
                    <div id="readme">
                        <article>
                            <p>README content.</p>
                            <a href="https://example.com/absolute/url">Absolute link.</a>
                            <a href="/root/relative/url">Root relative link.</a>
                            <a href="relative/url">Relative link.</a>
                            <a href="#anchor">Anchor link.</a>
                            <a>Invalid link.</a>
                        </article>
                    </div>
                </body>
            </html>
            """)

        let readme = try XCTUnwrap(model.readme)
        assertSnapshot(matching: readme, as: .lines)
    }
}
