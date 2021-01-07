@testable import App

import Fluent
import Vapor
import XCTVapor


final class TargetTests: AppTestCase {

    func test_save() throws {
        // setup
        let v = Version()
        try v.save(on: app.db).wait()
        let t = try Target(version: v, name: "target")

        // MUT
        try t.save(on: app.db).wait()

        // validate
        let readBack = try XCTUnwrap(Target.query(on: app.db).first().wait())
        XCTAssertNotNil(readBack.id)
        XCTAssertEqual(readBack.$version.id, v.id)
        XCTAssertNotNil(readBack.createdAt)
        XCTAssertNotNil(readBack.updatedAt)
        XCTAssertEqual(readBack.name, "target")
    }

    func test_delete_cascade() throws {
        // setup
        let v = Version()
        try v.save(on: app.db).wait()
        let t = try Target(version: v, name: "target")
        try t.save(on: app.db).wait()
        XCTAssertNotNil(try Target.query(on: app.db).first().wait())

        // MUT
        try v.delete(on: app.db).wait()

        // validate
        XCTAssertNil(try Target.query(on: app.db).first().wait())
    }

}
