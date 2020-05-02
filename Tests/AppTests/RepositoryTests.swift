@testable import App

import XCTVapor


final class RepositoryTests: AppTestCase {
    
    func test_package_relationship() throws {
        let pkg = Package(url: "p1".url)
        try pkg.save(on: app.db).wait()
        let repo = try Repository(package: pkg)
        try repo.save(on: app.db).wait()
        // test some ways to resolve the relationship
        XCTAssertEqual(repo.$package.id, pkg.id)
        XCTAssertEqual(try repo.$package.get(on: app.db).wait().url, "p1")

        // ensure one-to-one is in place
        do {
            let repo = try Repository(package: pkg)
            XCTAssertThrowsError(try repo.save(on: app.db).wait())
            XCTAssertEqual(try Repository.query(on: app.db).all().wait().count, 1)
        }
    }

    func test_forkedFrom_relationship() throws {
        let p1 = Package(url: "p1".url)
        try p1.save(on: app.db).wait()
        let p2 = Package(url: "p2".url)
        try p2.save(on: app.db).wait()

        // test forked from link
        let parent = try Repository(package: p1)
        try parent.save(on: app.db).wait()
        let child = try Repository(package: p2, forkedFrom: parent)
        try child.save(on: app.db).wait()
    }
}
