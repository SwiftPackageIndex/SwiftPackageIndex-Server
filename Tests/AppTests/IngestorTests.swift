@testable import App

import Fluent
import Vapor
import XCTest


class IngestorTests: AppTestCase {
    
    func test_ingest_basic() throws {
        // setup
        let urls = ["https://github.com/finestructure/Gala",
                    "https://github.com/finestructure/Rester",
                    "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server"]
        Current.fetchMetadata = { _, pkg in .just(value: .mock(for: pkg)) }
        let packages = try savePackages(on: app.db, urls.asURLs, processingStage: .reconciliation)
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
            XCTAssertEqual($0.defaultBranch, "main")
            XCTAssert($0.forks != nil && $0.forks! > 0)
            XCTAssert($0.stars != nil && $0.stars! > 0)
        }
        // assert packages have been updated
        (try Package.query(on: app.db).all().wait()).forEach {
            XCTAssert($0.updatedAt != nil && $0.updatedAt! > lastUpdate)
            XCTAssertEqual($0.status, .new)
            XCTAssertEqual($0.processingStage, .ingestion)
        }
    }

    func test_fetchMetadata() throws {
        // setup
        let packages = try savePackages(on: app.db, ["1", "2"].asURLs)
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
            md.repo.description = "New description"
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
            .success((pkg, .init(
                issues: [
                    .init(closedAt: Date(timeIntervalSince1970: 0), pullRequest: nil),
                    .init(closedAt: Date(timeIntervalSince1970: 1), pullRequest: .init(url: "1")),
                    .init(closedAt: Date(timeIntervalSince1970: 2), pullRequest: nil),
                ],
                openPullRequests: [
                    .init(url: "2"),
                    .init(url: "3"),
                ],
                repo: .init(defaultBranch: "main",
                            description: "package desc",
                            forksCount: 1,
                            license: .init(key: "mit"),
                            name: "bar",
                            openIssues: 3,
                            owner: .init(login: "foo"),
                            stargazersCount: 2))))
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
        XCTAssertEqual(repo.defaultBranch, "main")
        XCTAssertEqual(repo.forks, 1)
        XCTAssertEqual(repo.lastIssueClosedAt, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(repo.lastPullRequestClosedAt, Date(timeIntervalSince1970: 1))
        XCTAssertEqual(repo.license, .mit)
        XCTAssertEqual(repo.openIssues, 1)
        XCTAssertEqual(repo.openPullRequests, 2)
        XCTAssertEqual(repo.owner, "foo")
        XCTAssertEqual(repo.name, "bar")
        XCTAssertEqual(repo.stars, 2)
        XCTAssertEqual(repo.summary, "package desc")
    }

    func test_updatePackage() throws {
        // setup
        let pkgs = try savePackages(on: app.db, ["1", "2"])
        let results: [Result<Package, Error>] = [
            .failure(AppError.metadataRequestFailed(try pkgs[0].requireID(), .badRequest, "1")),
            .success(pkgs[1])
        ]

        // MUT
        try updatePackage(application: app, results: results, stage: .ingestion).wait()

        // validate
        do {
            let pkgs = try Package.query(on: app.db).sort(\.$url).all().wait()
            XCTAssertEqual(pkgs.map(\.status), [.metadataRequestFailed, .new])
            XCTAssertEqual(pkgs.map(\.processingStage), [.ingestion, .ingestion])
        }
    }

    func test_updatePackages_new() throws {
        // Ensure newly ingested packages are passed on with status = new to fast-track
        // them into analysis
        let pkgs = [
            Package(id: UUID(), url: "1", status: .ok, processingStage: .reconciliation),
            Package(id: UUID(), url: "2", status: .new, processingStage: .reconciliation)
            ]
        try pkgs.save(on: app.db).wait()
        let results: [Result<Package, Error>] = [ .success(pkgs[0]), .success(pkgs[1])]

        // MUT
        try updatePackage(application: app, results: results, stage: .ingestion).wait()

        // validate
        do {
            let pkgs = try Package.query(on: app.db).sort(\.$url).all().wait()
            XCTAssertEqual(pkgs.map(\.status), [.ok, .new])
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
        let packages = try savePackages(on: app.db, urls.asURLs, processingStage: .reconciliation)
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
                XCTAssertEqual($0.status, .new)
            }
            XCTAssert($0.updatedAt! > lastUpdate)
        }
    }

    func test_ingest_unique_owner_name_violation() throws {
        // Test error behaviour when two packages resolving to the same owner/name are ingested:
        //   - don't update package
        //   - don't create repository records
        //   - report critical error up to Rollbar
        // setup
        let urls = ["1".asGithubUrl, "2".asGithubUrl]
        let packages = try savePackages(on: app.db, urls.asURLs, processingStage: .reconciliation)
        // Return identical metadata for both packages, same as a for instance a redirected
        // package would after a rename / ownership change
        Current.fetchMetadata = { _, _ in .just(value: Github.Metadata(
                issues: [],
                openPullRequests: [],
                repo: .init(defaultBranch: "main",
                            description: "desc",
                            forksCount: 0,
                            name: "package name",
                            openIssues: 0,
                            owner: .some(.init(login: "owner")),
                            stargazersCount: 0)))
        }
        var reportedLevel: AppError.Level? = nil
        var reportedError: String? = nil
        Current.reportError = { _, level, error in
            // Errors seen here go to Rollbar
            reportedLevel = level
            reportedError = error.localizedDescription
            return .just(value: ())
        }
        let lastUpdate = Date()

        // MUT
        try ingest(application: app, database: app.db, limit: 10).wait()

        // validate repositories (single element pointing to first package)
        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(repos.map(\.$package.id), [packages[0].id])

        // validate packages
        let pkgs = try Package.query(on: app.db).sort(\.$url).all().wait()
        // the first package gets the update ...
        XCTAssertEqual(pkgs[0].status, .new)
        XCTAssertEqual(pkgs[0].processingStage, .ingestion)
        XCTAssert(pkgs[0].updatedAt! > lastUpdate)
        // ... the second package remains unchanged ...
        XCTAssertEqual(pkgs[1].status, .new)
        XCTAssertEqual(pkgs[1].processingStage, .reconciliation)
        XCTAssert(pkgs[1].updatedAt! < lastUpdate)
        // ... and an error report has been triggered
        XCTAssertEqual(reportedLevel, .critical)
        XCTAssert(reportedError?.contains("duplicate key value violates unique constraint") ?? false)
    }


}


