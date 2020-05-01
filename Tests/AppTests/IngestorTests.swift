@testable import App

import Fluent
import Vapor
import XCTest


class IngestorTests: AppTestCase {
    
    func test_ingest_basic() throws {
        // setup
        let urls = ["https://github.com/finestructure/Gala",
                    "https://github.com/finestructure/Rester",
                    "https://github.com/finestructure/SwiftPMLibrary-Server"]
        Current.fetchMetadata = { _, pkg in .just(value: .mock(for: pkg)) }
        let packages = try savePackages(on: app.db, urls.compactMap(URL.init(string:)))
        let lastUpdate = Date()

        // MUT
        try ingest(client: app.client, database: app.db, limit: 10).wait()

        // validate
        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(repos.map(\.$package.id), packages.map(\.id))
        repos.forEach {
            XCTAssertNotNil($0.id)
            XCTAssertNotNil($0.$package.id)
            XCTAssertNotNil($0.createdAt)
            XCTAssertNotNil($0.updatedAt)
            XCTAssertNotNil($0.description)
            XCTAssertEqual($0.defaultBranch, "master")
            XCTAssert($0.forks! > 0)
            XCTAssert($0.stars! > 0)
        }
        // assert packages have been updated
        (try Package.query(on: app.db).all().wait()).forEach {
            XCTAssert($0.updatedAt! > lastUpdate)
            XCTAssertEqual($0.status, .ok)
        }
    }

    func test_insertOrUpdateRepository() throws {
        let pkg = try savePackage(on: app.db, "foo".url)
        do {  // test insert
            try insertOrUpdateRepository(on: app.db, for: pkg, metadata: .mock(for: pkg)).wait()
            let repos = try Repository.query(on: app.db).all().wait()
            XCTAssertEqual(repos.map(\.description), [.some("This is package foo")])
        }
        do {  // test update - run the same package again, with different metadata
            var md = Github.Metadata.mock(for: pkg)
            md.description = "New description"
            try insertOrUpdateRepository(on: app.db, for: pkg, metadata: md).wait()
            let repos = try Repository.query(on: app.db).all().wait()
            XCTAssertEqual(repos.map(\.description), [.some("New description")])
        }
    }

    func test_partial_save_issue() throws {
        // setup
        Current.fetchMetadata = { _, pkg in .just(value: .mock(for: pkg)) }
        let packages = try savePackages(on: app.db, testUrls)

        // MUT
        try ingest(client: app.client, database: app.db, limit: testUrls.count).wait()

        // validate
        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(repos.count, testUrls.count)
        XCTAssertEqual(repos.map(\.$package.id), packages.map(\.id))
    }

    func test_insertOrUpdateRepository_bulk() throws {
        // test flattening of many updates
        // Mainly a debug test for the issue described here:
        // https://discordapp.com/channels/431917998102675485/444249946808647699/704335749637472327
        let packages = try savePackages(on: app.db, testUrls100)
        let req = try packages
            .map { ($0, Github.Metadata.mock(for: $0)) }
            .map { try insertOrUpdateRepository(on: self.app.db, for: $0.0, metadata: $0.1) }
            .flatten(on: app.db.eventLoop)

        try req.wait()

        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(repos.count, testUrls100.count)
        XCTAssertEqual(repos.map(\.$package.id.uuidString).sorted(),
                       packages.map(\.id).compactMap { $0?.uuidString }.sorted())
    }

    func test_fetchMetadata_badMetadata() throws {
        // setup
        let urls = ["1", "2", "3"]
        Current.fetchMetadata = { _, pkg in
            if pkg.url == "2" {
               return .just(error: AppError.metadataRequestFailed(nil, .badRequest, URI("2")))
            }
            return .just(value: .mock(for: pkg))
        }
        try savePackages(on: app.db, urls.compactMap(URL.init(string:)))

        // MUT
        let md = try fetchMetadata(client: app.client, database: app.db, limit: 10).wait()

        // validate
        XCTAssertEqual(md.count, 3)
        XCTAssertEqual(md.map(\.isSuccess), [true, false, true])
    }

    func test_recordIngestionError() throws {
        let pkg = try savePackage(on: app.db, "1".url)
        try recordIngestionError(database: app.db,
                                 error: AppError.invalidPackageUrl(pkg.id, "foo")).wait()
        XCTAssertEqual(try fetch(id: pkg.id, on: app.db).status, .invalidUrl)
    }

    func test_ingest_badMetadata() throws {
        // setup
        let urls = ["1", "2", "3"]
        let packages = try savePackages(on: app.db, urls.compactMap(URL.init(string:)))
        Current.fetchMetadata = { _, pkg in
            if pkg.url == "2" {
                return .just(error: AppError.metadataRequestFailed(packages[1].id, .badRequest, URI("2")))
            }
            return .just(value: .mock(for: pkg))
        }
        let lastUpdate = Date()

        // MUT
        try ingest(client: app.client, database: app.db, limit: 10).wait()

        // validate
        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(repos.count, 2)
        XCTAssertEqual(repos.map(\.description),
                       [.some("This is package 1"), .some("This is package 3")])
        (try Package.query(on: app.db).all().wait()).forEach {
            if $0.url == "2" {
                XCTAssertEqual($0.status, .metadataRequestFailed)
            } else {
                XCTAssertEqual($0.status, .ok)
            }
            XCTAssert($0.updatedAt! > lastUpdate)
        }
    }

}


