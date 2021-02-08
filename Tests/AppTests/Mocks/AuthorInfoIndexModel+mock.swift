@testable import App

import Foundation

extension AuthorInfoIndex.Model {

    static var mock: AuthorInfoIndex.Model {
        .init(packageName: "Example Package", repositoryOwner: "example", repositoryName: "package")
    }
}
