@testable import App

import Fluent
import Vapor
import XCTVapor


final class TargetTests: AppTestCase {

    func test_save() throws {
        let t = Target(name: "target")
        try t.save(on: app.db).wait()
        let readBack = try XCTUnwrap(Target.query(on: app.db).first().wait())
        XCTAssertNotNil(readBack.id)
        XCTAssertNotNil(readBack.createdAt)
        XCTAssertNotNil(readBack.updatedAt)
        XCTAssertEqual(readBack.name, "target")
    }

}
