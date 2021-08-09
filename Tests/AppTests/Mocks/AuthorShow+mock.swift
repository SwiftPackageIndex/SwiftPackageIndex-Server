@testable import App

import Foundation


extension AuthorShow.Model {
    static var mock: AuthorShow.Model {
        let packages = (1...10).map { PackageInfo(
            title: "vapor-\($0)",
            description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas nec orci scelerisque, interdum purus a, tempus turpis.",
            url: "",
            stars: 3
        ) }
        return .init(owner: "test-author", ownerName: "Test Author", packages: packages)
    }
}
