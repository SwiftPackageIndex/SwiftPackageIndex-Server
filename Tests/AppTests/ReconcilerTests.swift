@testable import App

import Vapor
import XCTest


class ReconcilerTests: AppTestCase {
    
    func test_basic_reconciliation() async throws {
        let urls = ["1", "2", "3"]
        Current.fetchPackageList = { _ in urls.asURLs }
        
        try await reconcile(client: app.client, database: app.db)
        
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
    
    func test_adds_and_deletes() async throws {
        // save intial set of packages 1, 2, 3
        try savePackages(on: app.db, ["1", "2", "3"].asURLs)
        
        // new package list drops 2, 3, adds 4, 5
        let urls = ["1", "4", "5"]
        Current.fetchPackageList = { _ in urls.asURLs }
        
        // MUT
        try await reconcile(client: app.client, database: app.db)
        
        // validate
        let packages = try Package.query(on: app.db).all().wait()
        XCTAssertEqual(packages.map(\.url).sorted(), urls.sorted())
    }
}
