// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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


class ReconcilerTests: AppTestCase {

    func test_fetchCurrentPackageList() async throws {
        // setup
        for url in ["1", "2", "3"].asURLs {
            try await Package(url: url).save(on: app.db)
        }

        // MUT
        let urls = try await fetchCurrentPackageList(app.db)

        // validate
        XCTAssertEqual(urls.map(\.absoluteString).sorted(), ["1", "2", "3"])
    }

    func test_basic_reconciliation() async throws {
        // setup
        let urls = ["1", "2", "3"]
        Current.fetchPackageList = { _ in urls.asURLs }

        // MUT
        try await reconcile(client: app.client, database: app.db)

        // validate
        let packages = try await Package.query(on: app.db).all()
        XCTAssertEqual(packages.map(\.url).sorted(), urls.sorted())
        packages.forEach {
            XCTAssertNotNil($0.id)
            XCTAssertNotNil($0.createdAt)
            XCTAssertNotNil($0.updatedAt)
            XCTAssertEqual($0.status, .new)
            XCTAssertEqual($0.processingStage, .reconciliation)
        }
    }

    func test_adds_and_deletes() async throws {
        // save intial set of packages 1, 2, 3
        for url in ["1", "2", "3"].asURLs {
            try await Package(url: url).save(on: app.db)
        }

        // new package list drops 2, 3, adds 4, 5
        let urls = ["1", "4", "5"]
        Current.fetchPackageList = { _ in urls.asURLs }

        // MUT
        try await reconcile(client: app.client, database: app.db)

        // validate
        let packages = try await Package.query(on: app.db).all()
        XCTAssertEqual(packages.map(\.url).sorted(), urls.sorted())
    }

    func test_packageDenyList() async throws {
        // Save the intial set of packages
        for url in ["1", "2", "3"].asURLs {
            try await Package(url: url).save(on: app.db)
        }

        // New list adds two new packages 4, 5
        let packageList = ["1", "2", "3", "4", "5"]
        Current.fetchPackageList = { _ in packageList.asURLs }

        // Deny list denies 2 and 4 (one existing and one new)
        let packageDenyList = ["2", "4"]
        Current.fetchPackageDenyList = { _ in packageDenyList.asURLs }

        // MUT
        try await reconcile(client: app.client, database: app.db)

        // validate
        let packages = try await Package.query(on: app.db).all()
        XCTAssertEqual(packages.map(\.url).sorted(), ["1", "3", "5"])
    }
}
