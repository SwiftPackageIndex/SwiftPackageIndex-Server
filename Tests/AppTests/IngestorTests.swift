@testable import App

import Fluent
import Vapor
import XCTest


class IngestorTests: XCTestCase {
    var app: Application!

    override func setUpWithError() throws {
        app = try setup(.testing)
    }

    override func tearDownWithError() throws {
        app.shutdown()
    }

    func test_basic_ingestion() throws {
        // setup
        let urls = ["https://github.com/finestructure/Gala",
                    "https://github.com/finestructure/Rester",
                    "https://github.com/finestructure/SwiftPMLibrary-Server"]
        Current.fetchMasterPackageList = { _ in .just(value: urls.urls) }
        Current.fetchRepository = { _, pkg in .just(value: .mock(for: pkg)) }
        let packages = try savePackages(on: app.db, urls.compactMap(URL.init(string:)))

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
    }

    func test_insertOrUpdateRepository() throws {
        let pkg = try savePackage(on: app.db, "https://github.com/finestructure/Gala".url)
        do {  // test insert
            try insertOrUpdateRepository(on: app.db, for: pkg, metadata: .mock(for: pkg)).wait()
            let repos = try Repository.query(on: app.db).all().wait()
            XCTAssertEqual(repos.map(\.description), [.some("This is package finestructure/Gala")])
        }
        do {  // test update - run the same package again, with different metadata
            var md = Github.Metadata.mock(for: pkg)
            md.description = "New description"
            try insertOrUpdateRepository(on: app.db, for: pkg, metadata: md).wait()
            let repos = try Repository.query(on: app.db).all().wait()
            XCTAssertEqual(repos.map(\.description), [.some("New description")])
        }
    }

    func test_insertOrUpdateRepository_bulk_simpler() throws {
        // test flattening of many updates
        let packages = try savePackages(on: app.db, testUrls100)
        let req = try packages
            .map { (Github.Metadata.mock(for: $0), $0) }
            .map { try insertOrUpdateRepository(on: self.app.db, for: $0.1, metadata: $0.0) }
            .flatten(on: app.db.eventLoop)

        try req.wait()

        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(repos.count, testUrls100.count)
        XCTAssertEqual(repos.map(\.$package.id.uuidString).sorted(),
                       packages.map(\.id).compactMap { $0?.uuidString }.sorted())
    }

    func test_bulk_metadata() throws {
        let input = app.db.eventLoop.future(
            testUrls100.map { Package(url: $0) } )  // EventLoopFuture<[URL]>
            .flatMapEachThrowing {
                EventLoopFuture<Github.Metadata>.just(value: Github.Metadata.mock(for: $0))
                    .and(value: $0)
        }
        .flatMap { $0.flatten(on: self.app.db.eventLoop) }
        let res = try input.wait()
        XCTAssertEqual(res.count, testUrls100.count)
    }

    func test_bulk_save_issue() throws {
        let input = app.db.eventLoop.future(
            testUrls100.map { Package(url: $0) } )  // EventLoopFuture<[URL]>
        let inserts = input
            .flatMapEachThrowing { try $0.create(on: self.app.db) }
            .flatMap { $0.flatten(on: self.app.db.eventLoop) }
        try inserts.wait()
        let packages = try Package.query(on: app.db).all().wait()
        XCTAssertEqual(packages.count, testUrls100.count)
    }

    func test_partial_save_issue() throws {
        // setup
        Current.fetchMasterPackageList = { _ in .just(value: testUrls) }
        Current.fetchRepository = { _, pkg in .just(value: .mock(for: pkg)) }
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
        let packages = try savePackages(on: app.db, testUrls100)
        let metadata = Package.query(on: app.db)
            .all()
            .flatMapEachThrowing {
                EventLoopFuture<Github.Metadata>.just(value: Github.Metadata.mock(for: $0))
                    .and(value: $0)
        }
        .flatMap { $0.flatten(on: self.app.db.eventLoop) }

        let resolvedMetadata = try metadata.wait()
        XCTAssertEqual(resolvedMetadata.count, 100)

        let req = app.db.eventLoop.future(resolvedMetadata)
            .flatMapThrowing { (arr) -> ([EventLoopFuture<Void>]) in
                let a = try arr.map { try insertOrUpdateRepository(on: self.app.db, for: $0.1, metadata: $0.0) }
                return a  //.flatten(on: self.app.db.eventLoop)
        }.flatMap { $0.flatten(on: self.app.db.eventLoop) }
        try req.wait()

        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(repos.count, testUrls100.count)
        XCTAssertEqual(repos.map(\.$package.id.uuidString).sorted(),
                       packages.map(\.id).compactMap { $0?.uuidString }.sorted())
    }

    func test_flatten() throws {
        // setup
        try savePackages(on: app.db, testUrls100)

        // test
        let foos = getFoos(app.client, app.db)
        let flattenedFoos = foos.flatMap { $0.flatten(on: self.app.db.eventLoop) }
        let inserts = flattenedFoos
            .flatMapEachThrowing { try doBar(on: self.app.db, with: $0) }
            .flatMap { $0.flatten(on: self.app.db.eventLoop) }

        try inserts.wait()

        XCTAssertEqual(try Bar.query(on: app.db).count().wait(), 100)
    }

    func test_flatten_upsert() throws {
        // setup
        try savePackages(on: app.db, testUrls100)

        // test
        let foos = getFoos(app.client, app.db)
        let flattenedFoos = foos.flatMap { $0.flatten(on: self.app.db.eventLoop) }
        let inserts = flattenedFoos
            .flatMapEachThrowing { try doBarUpsert(on: self.app.db, with: $0) }
            .flatMap { $0.flatten(on: self.app.db.eventLoop) }

        try inserts.wait()

        XCTAssertEqual(try Bar.query(on: app.db).count().wait(), 100)
    }

    func test_flatten_upsertNoBang() throws {
        // setup
        try savePackages(on: app.db, testUrls100)

        // test
        let foos = getFoos(app.client, app.db)
        let flattenedFoos = foos.flatMap { $0.flatten(on: self.app.db.eventLoop) }
        let inserts = flattenedFoos
            .flatMapEachThrowing { try doBarUpsertNoBang(on: self.app.db, with: $0) }
            .flatMap { $0.flatten(on: self.app.db.eventLoop) }

        try inserts.wait()

        XCTAssertEqual(try Bar.query(on: app.db).count().wait(), 100)
    }
}


typealias Foo = (Github.Metadata, Package)
typealias Bar = Repository

func getFoos(_ client: Client, _ database: Database) -> EventLoopFuture<[EventLoopFuture<Foo>]> {
    Package.query(on: database)
        .all()
        .flatMapEachThrowing { try Current.fetchRepository(client, $0).and(value: $0) }
}

func doBar(on database: Database, with foo: Foo) throws -> EventLoopFuture<Void> {
    try Repository(package: foo.1, metadata: foo.0).save(on: database)
}

func doBarUpsert(on database: Database, with foo: Foo) throws -> EventLoopFuture<Void> {
    let req = Repository.query(on: database)
        .filter(try \.$package.$id == foo.1.requireID())
        .first()
        .flatMap { (repo) -> EventLoopFuture<Void> in
            if let repo = repo {
                // update fields
                return repo.save(on: database)
            } else {
                return try! Repository(package: foo.1, metadata: foo.0).save(on: database)
            }
    }
    return req
}

func doBarUpsertNoBang(on database: Database, with foo: Foo) throws -> EventLoopFuture<Void> {
    let req = Repository.query(on: database)
        .filter(try \.$package.$id == foo.1.requireID())
        .first()
        .flatMap { (repo) -> EventLoopFuture<Void> in
            if let repo = repo {
                // update fields
                return repo.save(on: database)
            } else {
                do {
                    return try Repository(package: foo.1, metadata: foo.0).save(on: database)
                } catch {
                    return database.eventLoop.makeFailedFuture(Abort(.internalServerError))
                }
            }
    }
    return req
}

