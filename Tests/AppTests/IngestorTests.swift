// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import App

import Fluent
import Vapor
import XCTest


class IngestorTests: AppTestCase {
    
    func test_ingest_basic() async throws {
        // setup
        let urls = ["https://github.com/finestructure/Gala",
                    "https://github.com/finestructure/Rester",
                    "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server"]
        Current.fetchMetadata = { _, pkg in self.future(.mock(for: pkg)) }
        let packages = try savePackages(on: app.db, urls.asURLs, processingStage: .reconciliation)
        let lastUpdate = Date()
        
        // MUT
        try await ingest(client: app.client, database: app.db, logger: app.logger, mode: .limit(10))
        
        // validate
        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(Set(repos.map(\.$package.id)), Set(packages.map(\.id)))
        repos.forEach {
            XCTAssertNotNil($0.id)
            XCTAssertNotNil($0.$package.id)
            XCTAssertNotNil($0.createdAt)
            XCTAssertNotNil($0.updatedAt)
            XCTAssertNotNil($0.description)
            XCTAssertEqual($0.defaultBranch, "main")
            XCTAssert($0.forks > 0)
            XCTAssert($0.stars > 0)
        }
        // assert packages have been updated
        (try Package.query(on: app.db).all().wait()).forEach {
            XCTAssert($0.updatedAt != nil && $0.updatedAt! > lastUpdate)
            XCTAssertEqual($0.status, .new)
            XCTAssertEqual($0.processingStage, .ingestion)
        }
    }
    
    func test_fetchMetadata() async throws {
        // Test completion of all fetches despite early error
        // setup
        let packages = try savePackages(on: app.db, ["https://github.com/foo/1",
                                                     "https://github.com/foo/2"])
            .map(Joined<Package, Repository>.init(model:))
        Current.fetchMetadata = { _, pkg in
            if pkg.url == "https://github.com/foo/1" {
                return self.future(error: AppError.metadataRequestFailed(nil, .badRequest, URI("1")))
            }
            return self.future(.mock(for: pkg))
        }
        Current.fetchLicense = { _, _ in self.future(Github.License(htmlUrl: "license")) }

        // MUT
        let res = await fetchMetadata(client: app.client, packages: packages)
        
        // validate
        XCTAssertEqual(res.map(\.isSuccess), [false, true])
        let license = try XCTUnwrap(res.last?.get().2)
        XCTAssertEqual(license, .init(htmlUrl: "license"))
    }
    
    func test_insertOrUpdateRepository() async throws {
        let pkg = try savePackage(on: app.db, "https://github.com/foo/bar")
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()
        do {  // test insert
            try await insertOrUpdateRepository(on: app.db,
                                               for: jpr,
                                               metadata: .mock(for: pkg.url),
                                               licenseInfo: .init(htmlUrl: ""),
                                               readmeInfo: .init(downloadUrl: "", htmlUrl: ""))
            let repos = try Repository.query(on: app.db).all().wait()
            XCTAssertEqual(repos.map(\.summary), [.some("This is package https://github.com/foo/bar")])
        }
        do {  // test update - run the same package again, with different metadata
            var md = Github.Metadata.mock(for: pkg.url)
            md.repository?.description = "New description"
            try await insertOrUpdateRepository(on: app.db,
                                               for: jpr,
                                               metadata: md,
                                               licenseInfo: .init(htmlUrl: ""),
                                               readmeInfo: .init(downloadUrl: "", htmlUrl: ""))
            let repos = try Repository.query(on: app.db).all().wait()
            XCTAssertEqual(repos.map(\.summary), [.some("New description")])
        }
    }
    
    func test_updateRepositories() async throws {
        // setup
        let pkg = try savePackage(on: app.db, "2")
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()
        let metadata: [Result<(Joined<Package, Repository>, Github.Metadata, Github.License?, Github.Readme?),
                              Error>] = [
            .failure(AppError.metadataRequestFailed(nil, .badRequest, "1")),
            .success((jpr,
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
                            releases: [
                                .init(description: "a release",
                                      descriptionHTML: "<p>a release</p>",
                                      isDraft: false,
                                      publishedAt: Date(timeIntervalSince1970: 5),
                                      tagName: "1.2.3",
                                      url: "https://example.com/1.2.3")
                            ],
                            repositoryTopics: ["foo", "bar", "Bar", "baz"],
                            name: "bar",
                            stars: 2,
                            summary: "package desc",
                            isInOrganization: true),
                      licenseInfo: .init(htmlUrl: "license url"),
                      readmeInfo: .init(downloadUrl: "readme url", htmlUrl: "readme html url")))
        ]
        
        // MUT
        let res = await updateRepositories(on: app.db, metadata: metadata)
        
        // validate
        XCTAssertEqual(res.map(\.isSuccess), [false, true])
        let repo = try XCTUnwrap(
            Repository.query(on: app.db)
                .filter(\.$package.$id == pkg.requireID())
                .first().wait()
        )
        XCTAssertEqual(repo.defaultBranch, "main")
        XCTAssertEqual(repo.forks, 1)
        XCTAssertEqual(repo.isInOrganization, true)
        XCTAssertEqual(repo.keywords, ["bar", "baz", "foo"])
        XCTAssertEqual(repo.lastIssueClosedAt, Date(timeIntervalSince1970: 2))
        XCTAssertEqual(repo.lastPullRequestClosedAt, Date(timeIntervalSince1970: 3))
        XCTAssertEqual(repo.license, .mit)
        XCTAssertEqual(repo.licenseUrl, "license url")
        XCTAssertEqual(repo.openIssues, 1)
        XCTAssertEqual(repo.openPullRequests, 2)
        XCTAssertEqual(repo.owner, "foo")
        XCTAssertEqual(repo.ownerName, "foo")
        XCTAssertEqual(repo.ownerAvatarUrl, "https://avatars.githubusercontent.com/u/61124617?s=200&v=4")
        XCTAssertEqual(repo.readmeUrl, "readme url")
        XCTAssertEqual(repo.readmeHtmlUrl, "readme html url")
        XCTAssertEqual(repo.releases, [
            .init(description: "a release",
                  descriptionHTML: "<p>a release</p>",
                  isDraft: false,
                  publishedAt: Date(timeIntervalSince1970: 5),
                  tagName: "1.2.3",
                  url: "https://example.com/1.2.3")
        ])
        XCTAssertEqual(repo.name, "bar")
        XCTAssertEqual(repo.stars, 2)
        XCTAssertEqual(repo.summary, "package desc")
    }
    
    func test_updatePackage() throws {
        // setup
        let pkgs = try savePackages(on: app.db, ["https://github.com/foo/1",
                                                 "https://github.com/foo/2"])
            .map(Joined<Package, Repository>.init(model:))
        let results: [Result<Joined<Package, Repository>, Error>] = [
            .failure(AppError.metadataRequestFailed(try pkgs[0].model.requireID(), .badRequest, "1")),
            .success(pkgs[1])
        ]
        
        // MUT
        try updatePackages(client: app.client,
                           database: app.db,
                           logger: app.logger,
                           results: results,
                           stage: .ingestion).wait()
        
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
        let results: [Result<Joined<Package, Repository>, Error>] = [ .success(.init(model: pkgs[0])),
                                              .success(.init(model: pkgs[1]))]
        
        // MUT
        try updatePackages(client: app.client,
                           database: app.db,
                           logger: app.logger,
                           results: results,
                           stage: .ingestion).wait()
        
        // validate
        do {
            let pkgs = try Package.query(on: app.db).sort(\.$url).all().wait()
            XCTAssertEqual(pkgs.map(\.status), [.ok, .new])
            XCTAssertEqual(pkgs.map(\.processingStage), [.ingestion, .ingestion])
        }
    }
    
    func test_partial_save_issue() async throws {
        // Test to ensure futures are properly waited for and get flushed to the db in full
        // setup
        Current.fetchMetadata = { _, pkg in self.future(.mock(for: pkg)) }
        let packages = try savePackages(on: app.db, testUrls, processingStage: .reconciliation)
        
        // MUT
        try await ingest(client: app.client, database: app.db, logger: app.logger, mode: .limit(testUrls.count))
        
        // validate
        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(repos.count, testUrls.count)
        XCTAssertEqual(Set(repos.map(\.$package.id)), Set(packages.map(\.id)))
    }
    
    func test_insertOrUpdateRepository_bulk() async throws {
        // test flattening of many updates
        // Mainly a debug test for the issue described here:
        // https://discordapp.com/channels/431917998102675485/444249946808647699/704335749637472327
        let packages = try savePackages(on: app.db, testUrls100)
        try await packages
            .map { ($0, Github.Metadata.mock(for: $0.url)) }
            .forEachAsync {
                try await insertOrUpdateRepository(on: self.app.db,
                                                   for: .init(model: $0.0),
                                                   metadata: $0.1,
                                                   licenseInfo: .init(htmlUrl: ""),
                                                   readmeInfo: .init(downloadUrl: "", htmlUrl: ""))
            }
        
        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(repos.count, testUrls100.count)
        XCTAssertEqual(repos.map(\.$package.id.uuidString).sorted(),
                       packages.map(\.id).compactMap { $0?.uuidString }.sorted())
    }
    
    func test_ingest_badMetadata() async throws {
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
        try await ingest(client: app.client, database: app.db, logger: app.logger, mode: .limit(10))
        
        // validate
        let repos = try Repository.query(on: app.db).all().wait()
        XCTAssertEqual(repos.count, 2)
        XCTAssertEqual(repos.compactMap(\.summary).sorted(),
                       ["This is package https://github.com/foo/1",
                        "This is package https://github.com/foo/3"])
        (try Package.query(on: app.db).all().wait()).forEach { pkg in
            switch pkg.url {
                case "https://github.com/foo/2":
                    XCTAssertEqual(pkg.status, .metadataRequestFailed)
                default:
                    XCTAssertEqual(pkg.status, .new)
            }
            XCTAssert(pkg.updatedAt! > lastUpdate)
        }
    }
    
    func test_ingest_unique_owner_name_violation() async throws {
        // Test error behaviour when two packages resolving to the same owner/name are ingested:
        //   - don't update package
        //   - don't create repository records
        //   - report critical error up to Rollbar
        // setup
        let urls = ["https://github.com/foo/1", "https://github.com/foo/2"]
        try savePackages(on: app.db, urls.asURLs, processingStage: .reconciliation)
        // Return identical metadata for both packages, same as a for instance a redirected
        // package would after a rename / ownership change
        Current.fetchMetadata = { _, _ in self.future(
            Github.Metadata.init(
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
                summary: "desc",
                isInOrganization: false)
        )}
        var reportedLevel: AppError.Level? = nil
        var reportedError: String? = nil
        Current.reportError = { _, level, error in
            // Errors seen here go to Rollbar
            reportedLevel = level
            reportedError = error.localizedDescription
            return self.future(())
        }
        let lastUpdate = Date()
        
        // MUT
        try await ingest(client: app.client, database: app.db, logger: app.logger, mode: .limit(10))
        
        // validate repositories (single element pointing to the ingested package)
        let repos = try Repository.query(on: app.db).all().wait()
        let ingested = try XCTUnwrap(
            Package.query(on: app.db).filter(\.$processingStage == .ingestion)
                .first().wait()
        )
        XCTAssertEqual(repos.map(\.$package.id), [try ingested.requireID()])
        
        // validate packages
        let reconciled = try XCTUnwrap(
            Package.query(on: app.db).filter(\.$processingStage == .reconciliation)
                .first().wait()
        )
        // the ingested package has the update ...
        XCTAssertEqual(ingested.status, .new)
        XCTAssertEqual(ingested.processingStage, .ingestion)
        XCTAssert(ingested.updatedAt! > lastUpdate)
        // ... while the reconciled package remains unchanged ...
        XCTAssertEqual(reconciled.status, .new)
        XCTAssertEqual(reconciled.processingStage, .reconciliation)
        XCTAssert(reconciled.updatedAt! < lastUpdate)
        // ... and an error report has been triggered
        XCTAssertEqual(reportedLevel, .critical)
        XCTAssert(reportedError?.contains("duplicate key value violates unique constraint") ?? false)
    }
    
    func test_issue_761_no_license() async throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/761
        // setup
        let packages = try savePackages(on: app.db, ["https://github.com/foo/1"])
            .map(Joined<Package, Repository>.init(model:))
        // use mock for metadata request which we're not interested in ...
        Current.fetchMetadata = { _, _ in self.future(Github.Metadata()) }
        // and live fetch request for fetchLicense, whose behaviour we want to test ...
        Current.fetchLicense = Github.fetchLicense(client:packageUrl:)
        // and simulate its underlying request returning a 404 (by making all requests
        // return a 404, but it's the only one we're sending)
        let client = MockClient { _, resp in resp.status = .notFound }

        // MUT
        let res = await fetchMetadata(client: client, packages: packages)

        // validate
        XCTAssertEqual(res.map(\.isSuccess), [true], "future must be in success state")
        let license = try XCTUnwrap(res.first?.get()).2
        XCTAssertEqual(license, nil)
    }
}


