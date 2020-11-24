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
        Current.fetchMetadata = { _, pkg in self.future(.mock(for: pkg)) }
        let packages = try savePackages(on: app.db, urls.asURLs, processingStage: .reconciliation)
        let lastUpdate = Date()
        
        // MUT
        try ingest(application: app, limit: 10).wait()
        
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
        let packages = try savePackages(on: app.db, ["https://github.com/foo/1",
                                                     "https://github.com/foo/2"])
        Current.fetchMetadata = { _, pkg in
            if pkg.url == "https://github.com/foo/1" {
                return self.future(error: AppError.metadataRequestFailed(nil, .badRequest, URI("1")))
            }
            return self.future(.mock(for: pkg))
        }
        Current.fetchLicense = { _, _ in self.future(Github.License(htmlUrl: "license")) }

        // MUT
        let res = try fetchMetadata(client: app.client, packages: packages).wait()
        
        // validate
        XCTAssertEqual(res.map(\.isSuccess), [false, true])
        let license = try XCTUnwrap(res.last?.get().2)
        XCTAssertEqual(license, .init(htmlUrl: "license"))
    }
    
    func test_insertOrUpdateRepository() throws {
        let pkg = try savePackage(on: app.db, "https://github.com/foo/bar")
        do {  // test insert
            try insertOrUpdateRepository(on: app.db,
                                         for: pkg,
                                         metadata: .mock(for: pkg),
                                         licenseInfo: .init(htmlUrl: ""),
                                         readmeInfo: .init(downloadUrl: "")).wait()
            let repos = try Repository.query(on: app.db).all().wait()
            XCTAssertEqual(repos.map(\.summary), [.some("This is package https://github.com/foo/bar")])
        }
        do {  // test update - run the same package again, with different metadata
            var md = Github.Metadata.mock(for: pkg)
            md.repository?.description = "New description"
            try insertOrUpdateRepository(on: app.db,
                                         for: pkg,
                                         metadata: md,
                                         licenseInfo: .init(htmlUrl: ""),
                                         readmeInfo: .init(downloadUrl: "")).wait()
            let repos = try Repository.query(on: app.db).all().wait()
            XCTAssertEqual(repos.map(\.summary), [.some("New description")])
        }
    }
    
    func test_updateRepositories() throws {
        // setup
        let pkg = try savePackage(on: app.db, "2")
        let metadata: [Result<(Package, Github.Metadata, Github.License?, Github.Readme?),
                              Error>] = [
            .failure(AppError.metadataRequestFailed(nil, .badRequest, "1")),
            .success((pkg,
                      .init(defaultBranch: "main",
                            forks: 1,
                            issuesClosedAtDates: [
                                Date(timeIntervalSince1970: 0),
                                Date(timeIntervalSince1970: 2),
                                Date(timeIntervalSince1970: 1),
                            ],
                            license: .mit,
                            openIssues: 1,
                            openPullRequests: 2,
                            owner: "foo",
                            pullRequestsClosedAtDates: [
                                Date(timeIntervalSince1970: 1),
                                Date(timeIntervalSince1970: 3),
                                Date(timeIntervalSince1970: 2),
                            ],
                            name: "bar",
                            stars: 2,
                            summary: "package desc"),
                      licenseInfo: .init(htmlUrl: "license url"),
                      readmeInfo: .init(downloadUrl: "readme url")))
        ]
        
        // MUT
        let res = try updateRepositories(on: app.db, metadata: metadata).wait()
        
        // validate
        XCTAssertEqual(res.map(\.isSuccess), [false, true])
        let repo = try XCTUnwrap(
            Repository.query(on: app.db)
                .filter(\.$package.$id == pkg.requireID())
                .first().wait()
        )
        XCTAssertEqual(repo.defaultBranch, "main")
        XCTAssertEqual(repo.forks, 1)
        XCTAssertEqual(repo.lastIssueClosedAt, Date(timeIntervalSince1970: 2))
        XCTAssertEqual(repo.lastPullRequestClosedAt, Date(timeIntervalSince1970: 3))
        XCTAssertEqual(repo.license, .mit)
        XCTAssertEqual(repo.licenseUrl, "license url")
        XCTAssertEqual(repo.openIssues, 1)
        XCTAssertEqual(repo.openPullRequests, 2)
        XCTAssertEqual(repo.owner, "foo")
        XCTAssertEqual(repo.readmeUrl, "readme url")
        XCTAssertEqual(repo.name, "bar")
        XCTAssertEqual(repo.stars, 2)
        XCTAssertEqual(repo.summary, "package desc")
    }
    
    func test_updatePackage() throws {
        // setup
        let pkgs = try savePackages(on: app.db, ["https://github.com/foo/1",
                                                 "https://github.com/foo/2"])
        let results: [Result<Package, Error>] = [
            .failure(AppError.metadataRequestFailed(try pkgs[0].requireID(), .badRequest, "1")),
            .success(pkgs[1])
        ]
        
        // MUT
        try updatePackages(application: app, results: results, stage: .ingestion).wait()
        
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
            Package(id: UUID(), url: "https://github.com/foo/1", status: .ok, processingStage: .reconciliation),
            Package(id: UUID(), url: "https://github.com/foo/2", status: .new, processingStage: .reconciliation)
        ]
        try pkgs.save(on: app.db).wait()
        let results: [Result<Package, Error>] = [ .success(pkgs[0]), .success(pkgs[1])]
        
        // MUT
        try updatePackages(application: app, results: results, stage: .ingestion).wait()
        
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
        Current.fetchMetadata = { _, pkg in self.future(.mock(for: pkg)) }
        let packages = try savePackages(on: app.db, testUrls, processingStage: .reconciliation)
        
        // MUT
        try ingest(application: app, limit: testUrls.count).wait()
        
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
            .map { insertOrUpdateRepository(on: self.app.db,
                                            for: $0.0,
                                            metadata: $0.1,
                                            licenseInfo: .init(htmlUrl: ""),
                                            readmeInfo: .init(downloadUrl: "")) }
            .flatten(on: app.db.eventLoop)
        
        try req.wait()
        
        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(repos.count, testUrls100.count)
        XCTAssertEqual(repos.map(\.$package.id.uuidString).sorted(),
                       packages.map(\.id).compactMap { $0?.uuidString }.sorted())
    }
    
    func test_ingest_badMetadata() throws {
        // setup
        let urls = ["https://github.com/foo/1",
                    "https://github.com/foo/2",
                    "https://github.com/foo/3"]
        let packages = try savePackages(on: app.db, urls.asURLs, processingStage: .reconciliation)
        Current.fetchMetadata = { _, pkg in
            if pkg.url == "https://github.com/foo/2" {
                return self.future(error: AppError.metadataRequestFailed(packages[1].id, .badRequest, URI("2")))
            }
            return self.future(.mock(for: pkg))
        }
        let lastUpdate = Date()
        
        // MUT
        try ingest(application: app, limit: 10).wait()
        
        // validate
        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(repos.count, 2)
        XCTAssertEqual(repos.map(\.summary),
                       [.some("This is package https://github.com/foo/1"), .some("This is package https://github.com/foo/3")])
        (try Package.query(on: app.db).all().wait()).forEach {
            if $0.url == "https://github.com/foo/2" {
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
        let urls = ["https://github.com/foo/1", "https://github.com/foo/2"]
        let packages = try savePackages(on: app.db, urls.asURLs, processingStage: .reconciliation)
        // Return identical metadata for both packages, same as a for instance a redirected
        // package would after a rename / ownership change
        Current.fetchMetadata = { _, _ in self.future(Github.Metadata.init(
                                                    defaultBranch: "main",
                                                    forks: 0,
                                                    issuesClosedAtDates: [],
                                                    license: .mit,
                                                    openIssues: 0,
                                                    openPullRequests: 0,
                                                    owner: "owner",
                                                    pullRequestsClosedAtDates: [],
                                                    name: "name",
                                                    stars: 0,
                                                    summary: "desc"))
        }
        var reportedLevel: AppError.Level? = nil
        var reportedError: String? = nil
        Current.reportError = { _, level, error in
            // Errors seen here go to Rollbar
            reportedLevel = level
            reportedError = "\(error)"
            return self.future(())
        }
        let lastUpdate = Date()
        
        // MUT
        try ingest(application: app, limit: 10).wait()
        
        // validate repositories (single element pointing to first package)
        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(repos.map(\.$package.id), [packages[0].id].compactMap{ $0 })
        
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
    
    func test_issue_761_no_license() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/761
        // setup
        let packages = try savePackages(on: app.db, ["https://github.com/foo/1"])
        // use mock for metadata request which we're not interested in ...
        Current.fetchMetadata = { _, _ in self.future(Github.Metadata()) }
        // and live fetch request for fetchLicense, whose behaviour we want to test ...
        Current.fetchLicense = Github.fetchLicense(client:package:)
        // and simulate its underlying request returning a 404 (by making all requests
        // return a 404, but it's the only one we're sending)
        let client = MockClient { _, resp in resp.status = .notFound }

        // MUT
        let res = try fetchMetadata(client: client, packages: packages).wait()

        // validate
        XCTAssertEqual(res.map(\.isSuccess), [true], "future must be in success state")
        let license = try XCTUnwrap(res.first?.get()).2
        XCTAssertEqual(license, nil)
    }
}


