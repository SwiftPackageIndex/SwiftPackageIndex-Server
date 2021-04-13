@testable import App

import Foundation


extension PackageReadme.Model {
    static var mock: PackageReadme.Model {
        .init(readme: "This is README content.",
              readmeBaseUrl: "https://example.com/foo/bar/")
    }
}
