@testable import App

import Foundation


extension AuthorShow.Model {
    static var mock: AuthorShow.Model {
        let packages = (1...10).map { AuthorShow.PackageInfo(
            title: "vapor-\($0)",
            description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas nec orci scelerisque, interdum purus a, tempus turpis.",
            url: ""
        ) }
        return .init(owner: "test-author", ownerName: "Test Author", packages: packages)
    }
}
