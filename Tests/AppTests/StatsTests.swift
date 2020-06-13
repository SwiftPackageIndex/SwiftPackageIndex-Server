@testable import App

import XCTVapor


class StatsTests: AppTestCase {

    func test_fetch() throws {
        // setup
        // Save 2 packages and 5 versions
        do {
            let pkg = Package(id: UUID(), url: "1")
            try pkg.save(on: app.db).wait()
            try Version(package: pkg).create(on: app.db).wait()
            try Version(package: pkg).create(on: app.db).wait()
        }
        do {
            let pkg = Package(id: UUID(), url: "2")
            try pkg.save(on: app.db).wait()
            try Version(package: pkg).create(on: app.db).wait()
            try Version(package: pkg).create(on: app.db).wait()
            try Version(package: pkg).create(on: app.db).wait()
        }
        try Stats.refresh(on: app.db).wait()

        // MUT
        let res = try Stats.fetch(on: app.db).wait()

        // validate
        XCTAssertEqual(res, .some(.init(packageCount: 2, versionCount: 5)))
    }

}
