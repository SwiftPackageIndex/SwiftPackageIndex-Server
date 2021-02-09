@testable import App

import Foundation

extension MaintainerInfoIndex.Model {

    static var mock: MaintainerInfoIndex.Model {
        .init(packageName: "Example Package", repositoryOwner: "example", repositoryName: "package")
    }
}
