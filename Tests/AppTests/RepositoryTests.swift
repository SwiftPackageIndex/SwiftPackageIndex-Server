@testable import App

import XCTVapor


final class RepositoryTests: AppTestCase {

    func test_save() throws {
        let pkg = Package(id: UUID(), url: "1", status: .none)
        try pkg.save(on: app.db).wait()
        let repo = try Repository(id: UUID(),
                                  package: pkg,
                                  summary: "desc",
                                  commitCount: 123,
                                  firstCommitDate: Date(timeIntervalSince1970: 0),
                                  lastCommitDate: Date(timeIntervalSince1970: 1),
                                  defaultBranch: "branch",
                                  license: .mit,
                                  stars: 42,
                                  forks: 17,
                                  forkedFrom: nil)

        try repo.save(on: app.db).wait()

        do {
            let r = try XCTUnwrap(Repository.find(repo.id, on: app.db).wait())
            XCTAssertEqual(r.$package.id, pkg.id)
            XCTAssertEqual(r.summary, "desc")
            XCTAssertEqual(r.commitCount, 123)
            XCTAssertEqual(r.firstCommitDate, Date(timeIntervalSince1970: 0))
            XCTAssertEqual(r.lastCommitDate, Date(timeIntervalSince1970: 1))
            XCTAssertEqual(r.defaultBranch, "branch")
            XCTAssertEqual(r.license, .mit)
            XCTAssertEqual(r.stars, 42)
            XCTAssertEqual(r.forks, 17)
            XCTAssertEqual(r.forkedFrom, nil)
        }
    }
    
    func test_package_relationship() throws {
        let pkg = Package(url: "p1")
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
        let p1 = Package(url: "p1")
        try p1.save(on: app.db).wait()
        let p2 = Package(url: "p2")
        try p2.save(on: app.db).wait()

        // test forked from link
        let parent = try Repository(package: p1)
        try parent.save(on: app.db).wait()
        let child = try Repository(package: p2, forkedFrom: parent)
        try child.save(on: app.db).wait()
    }

    func test_delete_cascade() throws {
        // delete package must delete repository
        let pkg = Package(id: UUID(), url: "1", status: .none)
        let repo = try Repository(id: UUID(), package: pkg)
        try pkg.save(on: app.db).wait()
        try repo.save(on: app.db).wait()

        XCTAssertEqual(try Package.query(on: app.db).count().wait(), 1)
        XCTAssertEqual(try Repository.query(on: app.db).count().wait(), 1)

        // MUT
        try pkg.delete(on: app.db).wait()

        // version and product should be deleted
        XCTAssertEqual(try Package.query(on: app.db).count().wait(), 0)
        XCTAssertEqual(try Repository.query(on: app.db).count().wait(), 0)
    }

    func test_defaultBranch() throws {
        // setup
        let pkg = Package(id: UUID(), url: "1", status: .none)
        let repo = try Repository(id: UUID(), package: pkg, defaultBranch: "default")
        try pkg.save(on: app.db).wait()
        try repo.save(on: app.db).wait()

        // MUT
        let b = try Repository.defaultBranch(on: app.db, for: pkg).wait()

        // validate
        XCTAssertEqual(b, "default")
    }

}
