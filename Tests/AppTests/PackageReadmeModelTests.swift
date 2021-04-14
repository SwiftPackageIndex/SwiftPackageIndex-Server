@testable import App

import XCTVapor
import SnapshotTesting


class PackageReadmeModelTests: SnapshotTestCase {

    func test_readme_model() throws {
        var pkg = try savePackage(on: app.db, "https://github.com/Alamofire/Alamofire")

        try Repository(
            package: pkg,
            defaultBranch: "default",
            name: "Alamofire",
            owner: "Alamofire",
            readmeUrl: "https://raw.githubusercontent.com/Alamofire/Alamofire/master/README.md"
        ).save(on: app.db).wait()

        // reload via query to ensure relationships are loaded
        pkg = try Package.query(on: app.db,
                                owner: "Alamofire",
                                repository: "Alamofire").wait()

        let model = PackageReadme.Model(package: pkg, readme: "README Content.")

        XCTAssertEqual(model?.readmeBaseUrl, "https://raw.githubusercontent.com/Alamofire/Alamofire/master/")
    }

}
