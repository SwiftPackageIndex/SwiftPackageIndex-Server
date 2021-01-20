@testable import App

import Fluent
import SQLKit
import Vapor
import XCTest


class VersionReAnalyzerTests: AppTestCase {

    func test_reAnalyzeVersions() throws {
        // Basic end-to-end test
        // setup
        // - package dump does not include toolsVersion to simulate an "old version"
        // - run analysis to create existing version
        // - validate that toolsVersion is nil
        // - prepare package dump to report "5.3" before running MUT
        let pkg = try savePackage(on: app.db,
                                   "https://github.com/foo/1".url,
                                   processingStage: .ingestion)
        try Repository(package: pkg, defaultBranch: "main").save(on: app.db).wait()
        var pkgDump = #"""
            {
              "name": "SPI-Server",
              "products": [],
              "targets": []
            }
            """#
        Current.shell.run = { cmd, path in
            if cmd.string.hasSuffix("swift package dump-package") {
                return pkgDump
            }
            if cmd.string.hasPrefix(#"git log -n1 --format=format:"%H-%ct""#) { return "sha-0" }
            if cmd.string == "git rev-list --count HEAD" { return "12" }
            if cmd.string == #"git log --max-parents=0 -n1 --format=format:"%ct""# { return "0" }
            if cmd.string == #"git log -n1 --format=format:"%ct""# { return "1" }
            return ""
        }
        try analyze(client: app.client,
                    database: app.db,
                    logger: app.logger,
                    threadPool: app.threadPool,
                    limit: 10).wait()
        XCTAssertEqual(
            try Version.query(on: app.db).all().wait().map(\.toolsVersion),
            [nil]
        )
        // now include toolsVersion "5.3", effectively simulating the situation
        // where we only started parsing it after versions had already been created
        pkgDump = #"""
            {
              "name": "SPI-Server",
              "products": [],
              "targets": [],
              "toolsVersion": {
                "_version": "5.3"
              }
            }
            """#
        // running analysis again does not affect toolsVersion
        try analyze(client: app.client,
                    database: app.db,
                    logger: app.logger,
                    threadPool: app.threadPool,
                    limit: 10).wait()
        XCTAssertEqual(
            try Version.query(on: app.db).all().wait().map(\.toolsVersion),
            [nil]
        )

        // MUT
        try reAnalyzeVersions(client: app.client,
                              database: app.db,
                              logger: app.logger,
                              threadPool: app.threadPool,
                              versionsLastUpdatedBefore: Date(),
                              limit: 10).wait()

        // validate
        // ensure tools-version is now updated
        XCTAssertEqual(
            try Version.query(on: app.db).all().wait().map(\.toolsVersion),
            ["5.3"]
        )
    }

    func test_Package_fetchReAnalysisCandidates() throws {
        // Three packages with two versions:
        // 1) both versions updated before cutoff -> candidate
        // 2) one versino update before cutoff, one after -> candidate
        // 3) both version updated after cutoff -> no candidate
        let cutoff = Date(timeIntervalSince1970: 2)
        do {
            let p = Package(url: "1")
            try p.save(on: app.db).wait()
            try createVersion(app.db, p, updatedAt: 0)
            try createVersion(app.db, p, updatedAt: 1)
        }
        do {
            let p = Package(url: "2")
            try p.save(on: app.db).wait()
            try createVersion(app.db, p, updatedAt: 1)
            try createVersion(app.db, p, updatedAt: 3)
        }
        do {
            let p = Package(url: "3")
            try p.save(on: app.db).wait()
            try createVersion(app.db, p, updatedAt: 3)
            try createVersion(app.db, p, updatedAt: 4)
        }

        // MUT
        let res = try Package
            .fetchReAnalysisCandidates(app.db,
                                       versionsLastUpdatedBefore: cutoff,
                                       limit: 10).wait()

        // validate
        XCTAssertEqual(res.map(\.url), ["1", "2"])
    }

}


private func createVersion(_ db: Database,
                           _ package: Package,
                           updatedAt: Int) throws {
    let id = UUID()
    try Version(id: id, package: package).save(on: db).wait()
    let db = db as! SQLDatabase
    try db.raw("""
        update versions set updated_at = to_timestamp(\(bind: updatedAt))
        where id = \(bind: id)
        """)
        .run()
        .wait()
}
