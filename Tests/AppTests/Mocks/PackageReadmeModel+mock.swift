@testable import App

import Foundation


extension PackageReadme.Model {
    static var mock: PackageReadme.Model {
        .init(readme: """
            <div id="readme">
                <article>
                    <p>This is README content.</p>
                </article>
            </div>
            """, readmeBaseUrl: "https://example.com/foo/bar/")
    }
}
