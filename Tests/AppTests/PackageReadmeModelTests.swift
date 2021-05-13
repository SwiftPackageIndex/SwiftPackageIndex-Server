@testable import App

import XCTVapor
import SnapshotTesting


class PackageReadmeModelTests: SnapshotTestCase {

    func test_readme_model() throws {
        let model = PackageReadme.Model(readme: "README Content.")
        XCTAssertEqual(model.readme, "README Content.")
    }

}
