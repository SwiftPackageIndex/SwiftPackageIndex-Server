// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import App

import Vapor
import XCTest

class AuthorControllerTests: AppTestCase {
    
    let testPackageId: UUID = UUID()
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        let package = Package(id: testPackageId, url: "https://github.com/user/package.git")
        let repository = try Repository(id: UUID(),
                                        package: package,
                                        defaultBranch: "main",
                                        forks: 2,
                                        license: .mit,
                                        name: "package",
                                        owner: "owner",
                                        stars: 3,
                                        summary: "This is a test package")
        let version = try Version(id: UUID(),
                                  package: package,
                                  packageName: "Test package",
                                  reference: .branch("main"))
        let product = try Product(id: UUID(), version: version, type: .library(.automatic), name: "Library")
        
        try package.save(on: app.db).wait()
        try repository.save(on: app.db).wait()
        try version.save(on: app.db).wait()
        try product.save(on: app.db).wait()

        // re-load repository relationship (required for updateLatestVersions)
        try package.$repositories.load(on: app.db).wait()
        // update versions
        _ = try updateLatestVersions(on: app.db, package: package).wait()
    }

    func test_show_owner() throws {
        try app.test(.GET, "/owner", afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
        })
    }

    func test_show_owner_empty() throws {
        try app.test(.GET, "/fake-owner", afterResponse: { response in
            XCTAssertEqual(response.status, .notFound)
        })
    }

    func test_query_package_name() throws {
        // Ensure version.packageName is populated by query
        let packages = try AuthorController.query(on: app.db, owner: "owner")
            .wait()
        XCTAssertEqual(packages.map { $0.version?.packageName }, ["Test package"])
    }

}
