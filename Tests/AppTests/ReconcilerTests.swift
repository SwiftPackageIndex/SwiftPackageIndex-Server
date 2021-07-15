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


class ReconcilerTests: AppTestCase {
    
    func test_basic_reconciliation() throws {
        let urls = ["1", "2", "3"]
        Current.fetchPackageList = { _ in self.future(urls.asURLs) }
        
        try reconcile(client: app.client, database: app.db).wait()
        
        let packages = try Package.query(on: app.db).all().wait()
        XCTAssertEqual(packages.map(\.url).sorted(), urls.sorted())
        packages.forEach {
            XCTAssertNotNil($0.id)
            XCTAssertNotNil($0.createdAt)
            XCTAssertNotNil($0.updatedAt)
            XCTAssertEqual($0.status, .new)
            XCTAssertEqual($0.processingStage, .reconciliation)
        }
    }
    
    func test_adds_and_deletes() throws {
        // save intial set of packages 1, 2, 3
        try savePackages(on: app.db, ["1", "2", "3"].asURLs)
        
        // new package list drops 2, 3, adds 4, 5
        let urls = ["1", "4", "5"]
        Current.fetchPackageList = { _ in self.future(urls.asURLs) }
        
        // MUT
        try reconcile(client: app.client, database: app.db).wait()
        
        // validate
        let packages = try Package.query(on: app.db).all().wait()
        XCTAssertEqual(packages.map(\.url).sorted(), urls.sorted())
    }
}
