@testable import App

import Foundation


extension KeywordShow.Model {
    static var mock: Self {
        let packages = (1...10).map { PackageInfo(
            title: "Networking Package \($0)",
            description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas nec orci scelerisque, interdum purus a, tempus turpis.",
            url: ""
        ) }
        return .init(keyword: "networking", packages: packages, page: 1, hasMoreResults: false)
    }
}
