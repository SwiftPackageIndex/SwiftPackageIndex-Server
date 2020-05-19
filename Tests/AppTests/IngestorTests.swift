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
        let packages = try savePackages(on: app.db, urls.urls, processingStage: .reconciliation)
        let lastUpdate = Date()

        // MUT
        try ingest(application: app, database: app.db, limit: 10).wait()

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
            XCTAssertEqual($0.processingStage, .ingestion)
        }
    }

    func test_fetchMetadata() throws {
        // setup
        let packages = try savePackages(on: app.db, ["1", "2"].urls)
        Current.fetchMetadata = { _, pkg in
            if pkg.url == "1" {
               return .just(error: AppError.metadataRequestFailed(nil, .badRequest, URI("1")))
            }
            return .just(value: .mock(for: pkg))
        }

        // MUT
        let res = try fetchMetadata(client: app.client, packages: packages).wait()

        // validate
        XCTAssertEqual(res.map(\.isSuccess), [false, true])
    }

    func test_insertOrUpdateRepository() throws {
        let pkg = try savePackage(on: app.db, "foo")
        do {  // test insert
            try insertOrUpdateRepository(on: app.db, for: pkg, metadata: .mock(for: pkg)).wait()
            let repos = try Repository.query(on: app.db).all().wait()
            XCTAssertEqual(repos.map(\.summary), [.some("This is package foo")])
        }
        do {  // test update - run the same package again, with different metadata
            var md = Github.Metadata.mock(for: pkg)
            md.description = "New description"
            try insertOrUpdateRepository(on: app.db, for: pkg, metadata: md).wait()
            let repos = try Repository.query(on: app.db).all().wait()
            XCTAssertEqual(repos.map(\.summary), [.some("New description")])
        }
    }

    func test_updateRepositories() throws {
        // setup
        let pkg = try savePackage(on: app.db, "2")
        let metadata: [Result<(Package, Github.Metadata), Error>] = [
            .failure(AppError.metadataRequestFailed(nil, .badRequest, "1")),
            .success((pkg, .init(defaultBranch: "master",
                                 description: "package desc",
                                 forksCount: 1,
                                 license: .init(key: "mit"),
                                 name: "bar",
                                 owner: .init(login: "foo"),
                                 stargazersCount: 2)))
        ]

        // MUT
        let res = try updateRespositories(on: app.db, metadata: metadata).wait()

        // validate
        XCTAssertEqual(res.map(\.isSuccess), [false, true])
        let repo = try XCTUnwrap(
            Repository.query(on: app.db)
                .filter(\.$package.$id == pkg.requireID())
                .first().wait()
        )
        XCTAssertEqual(repo.defaultBranch, "master")
        XCTAssertEqual(repo.forks, 1)
        XCTAssertEqual(repo.license, .mit)
        XCTAssertEqual(repo.owner, "foo")
        XCTAssertEqual(repo.name, "bar")
        XCTAssertEqual(repo.stars, 2)
        XCTAssertEqual(repo.summary, "package desc")
    }

    func test_updateStatus() throws {
        // setup
        let pkgs = try savePackages(on: app.db, ["1", "2"])
        let results: [Result<Package, Error>] = [
            .failure(AppError.metadataRequestFailed(try pkgs[0].requireID(), .badRequest, "1")),
            .success(pkgs[1])
        ]

        // MUT
        try updateStatus(application: app, results: results, stage: .ingestion).wait()

        // validate
        do {
            let pkgs = try Package.query(on: app.db).sort(\.$url).all().wait()
            XCTAssertEqual(pkgs.map(\.status), [.metadataRequestFailed, .ok])
            XCTAssertEqual(pkgs.map(\.processingStage), [.ingestion, .ingestion])
        }
    }

    func test_partial_save_issue() throws {
        // Test to ensure futures are properly waited for and get flushed to the db in full
        // setup
        Current.fetchMetadata = { _, pkg in .just(value: .mock(for: pkg)) }
        let packages = try savePackages(on: app.db, testUrls, processingStage: .reconciliation)

        // MUT
        try ingest(application: app, database: app.db, limit: testUrls.count).wait()

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
        let req = packages
            .map { ($0, Github.Metadata.mock(for: $0)) }
            .map { insertOrUpdateRepository(on: self.app.db, for: $0.0, metadata: $0.1) }
            .flatten(on: app.db.eventLoop)

        try req.wait()

        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(repos.count, testUrls100.count)
        XCTAssertEqual(repos.map(\.$package.id.uuidString).sorted(),
                       packages.map(\.id).compactMap { $0?.uuidString }.sorted())
    }

    func test_ingest_badMetadata() throws {
        // setup
        let urls = ["1", "2", "3"]
        let packages = try savePackages(on: app.db, urls.urls, processingStage: .reconciliation)
        Current.fetchMetadata = { _, pkg in
            if pkg.url == "2" {
                return .just(error: AppError.metadataRequestFailed(packages[1].id, .badRequest, URI("2")))
            }
            return .just(value: .mock(for: pkg))
        }
        let lastUpdate = Date()

        // MUT
        try ingest(application: app, database: app.db, limit: 10).wait()

        // validate
        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(repos.count, 2)
        XCTAssertEqual(repos.map(\.summary),
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


