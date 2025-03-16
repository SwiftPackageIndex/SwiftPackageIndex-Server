// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Dependencies
import Fluent
import S3Store
import Testing
import Vapor


extension AllTests.IngestionTests {

    @Test func ingest_basic() async throws {
        try await withApp { app in
            // setup
            let packages = ["https://github.com/finestructure/Gala",
                            "https://github.com/finestructure/Rester",
                            "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server"]
                .map { Package(url: $0, processingStage: .reconciliation) }
            try await packages.save(on: app.db)
            let lastUpdate = Date()

            try await withDependencies {
                $0.date.now = .now
                $0.github.fetchLicense = { @Sendable _, _ in nil }
                $0.github.fetchMetadata = { @Sendable owner, repository in .mock(owner: owner, repository: repository) }
                $0.github.fetchReadme = { @Sendable _, _ in nil }
            } operation: {
                // MUT
                try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(10))
            }

            // validate
            let repos = try await Repository.query(on: app.db).all()
            #expect(Set(repos.map(\.$package.id)) == Set(packages.map(\.id)))
            repos.forEach {
                #expect($0.id != nil)
                #expect($0.createdAt != nil)
                #expect($0.updatedAt != nil)
                #expect($0.defaultBranch == "main")
                #expect($0.forks > 0)
                #expect($0.stars > 0)
            }
            // assert packages have been updated
            (try await Package.query(on: app.db).all()).forEach {
                #expect($0.updatedAt != nil && $0.updatedAt! > lastUpdate)
                #expect($0.status == .new)
                #expect($0.processingStage == .ingestion)
            }
        }
    }

    @Test func ingest_continue_on_error() async throws {
        // Test completion of ingestion despite early error
        try await withDependencies {
            $0.github.fetchLicense = { @Sendable _, _ in Github.License(htmlUrl: "license") }
            $0.github.fetchMetadata = { @Sendable owner, repository throws(Github.Error) in
                if owner == "foo" && repository == "1" {
                    throw Github.Error.requestFailed(.badRequest)
                }
                return .mock(owner: owner, repository: repository)
            }
            $0.github.fetchReadme = { @Sendable _, _ in nil }
        } operation: {
            try await withApp { app in
            // setup
            let packages = try await savePackages(on: app.db, ["https://github.com/foo/1",
                                                               "https://github.com/foo/2"], processingStage: .reconciliation)
                .map(Joined<Package, Repository>.init(model:))

            // MUT
            await Ingestion.ingest(client: app.client, database: app.db, packages: packages)

                do {
                    // validate the second package's license is updated
                    let repo = try await Repository.query(on: app.db)
                        .filter(\.$name == "2")
                        .first()
                        .unwrap()
                    #expect(repo.licenseUrl == "license")
                    for pkg in try await Package.query(on: app.db).all() {
                        #expect(pkg.processingStage == .ingestion, "\(pkg.url) must be in ingestion")
                    }
                }
            }
        }
    }

    @Test func updateRepository_insert() async throws {
        try await withApp { app in
            let pkg = try await savePackage(on: app.db, "https://github.com/foo/bar")
            let repo = Repository(packageId: try pkg.requireID())

            // MUT
            try await Ingestion.updateRepository(on: app.db,
                                                 for: repo,
                                                 metadata: .mock(owner: "foo", repository: "bar"),
                                                 licenseInfo: .init(htmlUrl: ""),
                                                 readmeInfo: .init(html: "", htmlUrl: "", imagesToCache: []),
                                                 s3Readme: nil)

            // validate
            do {
                #expect(try await Repository.query(on: app.db).count() == 1)
                let repo = try await Repository.query(on: app.db).first().unwrap()
                #expect(repo.summary == "This is package foo/bar")
            }
        }
    }

    @Test func updateRepository_update() async throws {
        try await withApp { app in
            let pkg = try await savePackage(on: app.db, "https://github.com/foo/bar")
            let repo = Repository(packageId: try pkg.requireID())
            let md: Github.Metadata = .init(defaultBranch: "main",
                                            forks: 1,
                                            fundingLinks: [
                                                .init(platform: .gitHub, url: "https://github.com/username"),
                                                .init(platform: .customUrl, url: "https://example.com/username1"),
                                                .init(platform: .customUrl, url: "https://example.com/username2")
                                            ],
                                            homepageUrl: "https://swiftpackageindex.com/Alamofire/Alamofire",
                                            isInOrganization: true,
                                            issuesClosedAtDates: [
                                                Date(timeIntervalSince1970: 0),
                                                Date(timeIntervalSince1970: 2),
                                                Date(timeIntervalSince1970: 1),
                                            ],
                                            license: .mit,
                                            openIssues: 1,
                                            parentUrl: nil,
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
                                            summary: "package desc")

            // MUT
            try await Ingestion.updateRepository(on: app.db,
                                                 for: repo,
                                                 metadata: md,
                                                 licenseInfo: .init(htmlUrl: "license url"),
                                                 readmeInfo: .init(etag: "etag",
                                                                   html: "readme html https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com",
                                                                   htmlUrl: "readme html url",
                                                                   imagesToCache: []),
                                                 s3Readme: .cached(s3ObjectUrl: "url", githubEtag: "etag"),
                                                 fork: .parentURL("https://github.com/foo/bar.git"))

            // validate
            do {
                #expect(try await Repository.query(on: app.db).count() == 1)
                let repo = try await Repository.query(on: app.db).first().unwrap()
                #expect(repo.defaultBranch == "main")
                #expect(repo.forks == 1)
                #expect(repo.forkedFrom == .parentURL("https://github.com/foo/bar.git"))
                #expect(repo.fundingLinks == [
                    .init(platform: .gitHub, url: "https://github.com/username"),
                    .init(platform: .customUrl, url: "https://example.com/username1"),
                    .init(platform: .customUrl, url: "https://example.com/username2")
                ])
                #expect(repo.hasSPIBadge == true)
                #expect(repo.homepageUrl == "https://swiftpackageindex.com/Alamofire/Alamofire")
                #expect(repo.isInOrganization == true)
                #expect(repo.keywords == ["bar", "baz", "foo"])
                #expect(repo.lastIssueClosedAt == Date(timeIntervalSince1970: 2))
                #expect(repo.lastPullRequestClosedAt == Date(timeIntervalSince1970: 3))
                #expect(repo.license == .mit)
                #expect(repo.licenseUrl == "license url")
                #expect(repo.openIssues == 1)
                #expect(repo.openPullRequests == 2)
                #expect(repo.owner == "foo")
                #expect(repo.ownerName == "foo")
                #expect(repo.ownerAvatarUrl == "https://avatars.githubusercontent.com/u/61124617?s=200&v=4")
                #expect(repo.s3Readme == .cached(s3ObjectUrl: "url", githubEtag: "etag"))
                #expect(repo.readmeHtmlUrl == "readme html url")
                #expect(repo.releases == [
                    .init(description: "a release",
                          descriptionHTML: "<p>a release</p>",
                          isDraft: false,
                          publishedAt: Date(timeIntervalSince1970: 5),
                          tagName: "1.2.3",
                          url: "https://example.com/1.2.3")
                ])
                #expect(repo.name == "bar")
                #expect(repo.stars == 2)
                #expect(repo.summary == "package desc")
            }
        }
    }

    @Test func homePageEmptyString() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "2")
            let repo = Repository(packageId: try pkg.requireID())
            let md: Github.Metadata = .init(defaultBranch: "main",
                                            forks: 1,
                                            homepageUrl: "  ",
                                            isInOrganization: true,
                                            issuesClosedAtDates: [],
                                            license: .mit,
                                            openIssues: 1,
                                            parentUrl: nil,
                                            openPullRequests: 2,
                                            owner: "foo",
                                            pullRequestsClosedAtDates: [],
                                            releases: [],
                                            repositoryTopics: ["foo", "bar", "Bar", "baz"],
                                            name: "bar",
                                            stars: 2,
                                            summary: "package desc")

            // MUT
            try await Ingestion.updateRepository(on: app.db,
                                                 for: repo,
                                                 metadata: md,
                                                 licenseInfo: .init(htmlUrl: "license url"),
                                                 readmeInfo: .init(html: "readme html",
                                                                   htmlUrl: "readme html url",
                                                                   imagesToCache: []),
                                                 s3Readme: nil)

            // validate
            do {
                let repo = try await Repository.query(on: app.db).first().unwrap()
                #expect(repo.homepageUrl == nil)
            }
        }
    }

    @Test func updatePackage() async throws {
        try await withApp { app in
            // setup
            let pkgs = try await savePackages(on: app.db, ["https://github.com/foo/1",
                                                           "https://github.com/foo/2"])
                .map(Joined<Package, Repository>.init(model:))
            let pkgId0 = try pkgs[0].model.requireID()
            let results: [Result<Joined<Package, Repository>, Ingestion.Error>] = [
                .failure(.init(packageId: pkgId0, underlyingError: .fetchMetadataFailed(owner: "", name: "", details: ""))),
                .success(pkgs[1])
            ]

            // MUT
            for result in results {
                try await Ingestion.updatePackage(client: app.client,
                                                  database: app.db,
                                                  result: result,
                                                  stage: .ingestion)
            }

            // validate
            do {
                let pkgs = try await Package.query(on: app.db).sort(\.$url).all()
                #expect(pkgs.map(\.status) == [.ingestionFailed, .new])
                #expect(pkgs.map(\.processingStage) == [.ingestion, .ingestion])
            }
        }
    }

    @Test func updatePackage_new() async throws {
        // Ensure newly ingested packages are passed on with status = new to fast-track
        // them into analysis
        try await withApp { app in
            let pkgs = [
                Package(id: UUID(), url: "https://github.com/foo/1", status: .ok, processingStage: .reconciliation),
                Package(id: UUID(), url: "https://github.com/foo/2", status: .new, processingStage: .reconciliation)
            ]
            try await pkgs.save(on: app.db)
            let results: [Result<Joined<Package, Repository>, Ingestion.Error>] = [ .success(.init(model: pkgs[0])),
                                                                                    .success(.init(model: pkgs[1]))]
            
            // MUT
            for result in results {
                try await Ingestion.updatePackage(client: app.client,
                                                  database: app.db,
                                                  result: result,
                                                  stage: .ingestion)
            }
            
            // validate
            do {
                let pkgs = try await Package.query(on: app.db).sort(\.$url).all()
                #expect(pkgs.map(\.status) == [.ok, .new])
                #expect(pkgs.map(\.processingStage) == [.ingestion, .ingestion])
            }
        }
    }

    @Test func partial_save_issue() async throws {
        // Test to ensure futures are properly waited for and get flushed to the db in full
        try await withApp { app in
            // setup
            let packages = testUrls.map { Package(url: $0, processingStage: .reconciliation) }
            try await packages.save(on: app.db)

            try await withDependencies {
                $0.date.now = .now
                $0.github.fetchLicense = { @Sendable _, _ in nil }
                $0.github.fetchMetadata = { @Sendable owner, repository in .mock(owner: owner, repository: repository) }
                $0.github.fetchReadme = { @Sendable _, _ in nil }
            } operation: {
                // MUT
                try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(testUrls.count))
            }

            // validate
            let repos = try await Repository.query(on: app.db).all()
            #expect(repos.count == testUrls.count)
            #expect(Set(repos.map(\.$package.id)) == Set(packages.map(\.id)))
        }
    }

    @Test func ingest_badMetadata() async throws {
        // setup
        try await withApp { app in
            let urls = ["https://github.com/foo/1",
                        "https://github.com/foo/2",
                        "https://github.com/foo/3"]
            try await savePackages(on: app.db, urls.asURLs, processingStage: .reconciliation)
            let lastUpdate = Date()

            try await withDependencies {
                $0.date.now = .now
                $0.github.fetchLicense = { @Sendable _, _ in nil }
                $0.github.fetchMetadata = { @Sendable owner, repository throws(Github.Error) in
                    if owner == "foo" && repository == "2" {
                        throw Github.Error.requestFailed(.badRequest)
                    }
                    return .mock(owner: owner, repository: repository)
                }
                $0.github.fetchReadme = { @Sendable _, _ in nil }
            } operation: {
                // MUT
                try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(10))
            }

            // validate
            let repos = try await Repository.query(on: app.db).all()
            #expect(repos.count == 2)
            #expect(repos.compactMap(\.summary).sorted() == ["This is package foo/1",
                                                             "This is package foo/3"])
            (try await Package.query(on: app.db).all()).forEach { pkg in
                switch pkg.url {
                    case "https://github.com/foo/2":
                        #expect(pkg.status == .ingestionFailed)
                    default:
                        #expect(pkg.status == .new)
                }
                #expect(pkg.updatedAt! > lastUpdate)
            }
        }
    }

    @Test func ingest_unique_owner_name_violation() async throws {
        // Test error behaviour when two packages resolving to the same owner/name are ingested:
        //   - don't create repository records
        let capturingLogger = CapturingLogger()
        try await withApp { app in
            // setup
            try await Package(id: .id0, url: "https://github.com/foo/0", status: .ok, processingStage: .reconciliation)
                .save(on: app.db)
            try await Package(id: .id1, url: "https://github.com/foo/1", status: .ok, processingStage: .reconciliation)
                .save(on: app.db)

            try await withDependencies {
                $0.date.now = .now
                $0.github.fetchLicense = { @Sendable _, _ in nil }
                // Return identical metadata for both packages, same as a for instance a redirected
                // package would after a rename / ownership change
                $0.github.fetchMetadata = { @Sendable _, _ in
                    Github.Metadata.init(
                        defaultBranch: "main",
                        forks: 0,
                        homepageUrl: nil,
                        isInOrganization: false,
                        issuesClosedAtDates: [],
                        license: .mit,
                        openIssues: 0,
                        parentUrl: nil,
                        openPullRequests: 0,
                        owner: "owner",
                        pullRequestsClosedAtDates: [],
                        name: "name",
                        stars: 0,
                        summary: "desc")
                }
                $0.github.fetchReadme = { @Sendable _, _ in nil }
                $0.logger = .testLogger(capturingLogger)
            } operation: {
                // MUT
                try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(10))
            }

            // validate repositories (single element pointing to the ingested package)
            let repos = try await Repository.query(on: app.db).all()
            #expect(repos.count == 1)

            // validate packages - one should have succeeded, one should have failed
            let succeeded = try await Package.query(on: app.db)
                .filter(\.$status == .ok)
                .first()
                .unwrap()
            let failed = try await Package.query(on: app.db)
                .filter(\.$status == .ingestionFailed)
                .first()
                .unwrap()
            #expect(succeeded.processingStage == .ingestion)
            #expect(failed.processingStage == .ingestion)
            // an error must have been logged
            try capturingLogger.logs.withValue { logs in
                #expect(logs.count == 1)
                let log = try #require(logs.first)
                #expect(log.level == .critical)
                let id = try failed.requireID()
                #expect(log.message == #"Ingestion.Error(\#(id), repositorySaveUniqueViolation(owner, name, duplicate key value violates unique constraint "idx_repositories_owner_name"))"#)
            }

            // ensure analysis can process these packages
            try await withDependencies {
                $0.date.now = .now
                $0.environment.allowSocialPosts = { false }
                $0.environment.loadSPIManifest = { _ in nil }
                $0.fileManager.fileExists = { @Sendable _ in true }
                $0.git.commitCount = { @Sendable _ in 1 }
                $0.git.firstCommitDate = { @Sendable _ in .t0 }
                $0.git.getTags = { @Sendable _ in [] }
                $0.git.hasBranch = { @Sendable _, _ in true }
                $0.git.lastCommitDate = { @Sendable _ in .t0 }
                $0.git.revisionInfo = { @Sendable _, _ in .init(commit: "sha0", date: .t0) }
                $0.git.shortlog = { @Sendable _ in "" }
                $0.shell.run = { @Sendable cmd, _ in
                    if cmd.description.hasSuffix("package dump-package") {
                        return .packageDump(name: "foo")
                    }
                    return ""
                }
            } operation: { [db = app.db] in
                try await Analyze.analyze(client: app.client, database: db, mode: .id(.id0))
                try await Analyze.analyze(client: app.client, database: db, mode: .id(.id1))
                #expect(try await Package.find(.id0, on: db)?.processingStage == .analysis)
                #expect(try await Package.find(.id1, on: db)?.processingStage == .analysis)
            }
        }
    }

    @Test func S3Store_Key_readme() throws {
        try withDependencies {
            $0.environment.awsReadmeBucket = { "readme-bucket" }
        } operation: { () throws in
            #expect(try S3Store.Key.readme(owner: "foo", repository: "bar").path == "foo/bar/readme.html")
            #expect(try S3Store.Key.readme(owner: "FOO", repository: "bar").path == "foo/bar/readme.html")
        }
    }

    @Test func ingest_storeS3Readme() async throws {
        let fetchCalls = QueueIsolated(0)
        let storeCalls = QueueIsolated(0)
        try await withDependencies {
            $0.date.now = .now
            $0.github.fetchLicense = { @Sendable _, _ in nil }
            $0.github.fetchMetadata = { @Sendable owner, repository in .mock(owner: owner, repository: repository) }
            $0.github.fetchReadme = { @Sendable _, _ in
                fetchCalls.increment()
                if fetchCalls.value <= 2 {
                    return .init(etag: "etag1",
                                 html: "readme html 1",
                                 htmlUrl: "readme url",
                                 imagesToCache: [])
                } else {
                    return .init(etag: "etag2",
                                 html: "readme html 2",
                                 htmlUrl: "readme url",
                                 imagesToCache: [])
                }
            }
            $0.s3.storeReadme = { owner, repo, html in
                storeCalls.increment()
                #expect(owner == "foo")
                #expect(repo == "bar")
                if fetchCalls.value <= 2 {
                    #expect(html == "readme html 1")
                } else {
                    #expect(html == "readme html 2")
                }
                return "objectUrl"
            }
        } operation: {
            try await withApp { app in
                // setup
                let pkg = Package(url: "https://github.com/foo/bar".url, processingStage: .reconciliation)
                try await pkg.save(on: app.db)

                do { // first ingestion, no readme has been saved
                     // MUT
                    try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(1))

                    // validate
                    #expect(try await Repository.query(on: app.db).count() == 1)
                    let repo = try #require(await Repository.query(on: app.db).first())
                    // Ensure fetch and store have been called, etag save to repository
                    #expect(fetchCalls.value == 1)
                    #expect(storeCalls.value == 1)
                    #expect(repo.s3Readme == .cached(s3ObjectUrl: "objectUrl", githubEtag: "etag1"))
                }

                do { // second pass, readme has been saved, no new save should be issued
                    pkg.processingStage = .reconciliation
                    try await pkg.save(on: app.db)

                    // MUT
                    try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(1))

                    // validate
                    #expect(try await Repository.query(on: app.db).count() == 1)
                    let repo = try #require(await Repository.query(on: app.db).first())
                    // Ensure fetch and store have been called, etag save to repository
                    #expect(fetchCalls.value == 2)
                    #expect(storeCalls.value == 1)
                    #expect(repo.s3Readme == .cached(s3ObjectUrl: "objectUrl", githubEtag: "etag1"))
                }

                do { // third pass, readme has changed upstream, save should be issues
                    pkg.processingStage = .reconciliation
                    try await pkg.save(on: app.db)

                    // MUT
                    try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(1))

                    // validate
                    #expect(try await Repository.query(on: app.db).count() == 1)
                    let repo = try #require(await Repository.query(on: app.db).first())
                    // Ensure fetch and store have been called, etag save to repository
                    #expect(fetchCalls.value == 3)
                    #expect(storeCalls.value == 2)
                    #expect(repo.s3Readme == .cached(s3ObjectUrl: "objectUrl", githubEtag: "etag2"))
                }
            }
        }
    }

    @Test func ingest_storeS3Readme_withPrivateImages() async throws {
        try await withApp { app in
            let pkg = Package(url: "https://github.com/foo/bar".url,
                              processingStage: .reconciliation)
            try await pkg.save(on: app.db)
            let storeS3ReadmeImagesCalls = QueueIsolated(0)

            try await withDependencies {
                $0.date.now = .now
                $0.github.fetchLicense = { @Sendable _, _ in nil }
                $0.github.fetchMetadata = { @Sendable owner, repository in .mock(owner: owner, repository: repository) }
                $0.github.fetchReadme = { @Sendable _, _ in
                    return .init(etag: "etag",
                                 html: """
                         <html>
                         <body>
                             <img src="https://private-user-images.githubusercontent.com/with-jwt-1.jpg?jwt=some-jwt" />
                             <img src="https://private-user-images.githubusercontent.com/with-jwt-2.jpg?jwt=some-jwt" />
                             <img src="https://private-user-images.githubusercontent.com/without-jwt.jpg" />
                         </body>
                         </html>
                         """,
                                 htmlUrl: "readme url",
                                 imagesToCache: [
                                    .init(originalUrl: "https://private-user-images.githubusercontent.com/with-jwt-1.jpg?jwt=some-jwt",
                                          s3Key: .init(bucket: "awsReadmeBucket",
                                                       path: "/foo/bar/with-jwt-1.jpg")),
                                    .init(originalUrl: "https://private-user-images.githubusercontent.com/with-jwt-2.jpg?jwt=some-jwt",
                                          s3Key: .init(bucket: "awsReadmeBucket",
                                                       path: "/foo/bar/with-jwt-2.jpg"))
                                 ])
                }
                $0.s3.storeReadme = { _, _, _ in "objectUrl" }
                $0.s3.storeReadmeImages = { imagesToCache in
                    storeS3ReadmeImagesCalls.increment()
                    #expect(imagesToCache.count == 2)
                }
            } operation: {
                // MUT
                try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(1))
            }

            // There should only be one call as `storeS3ReadmeImages` takes the array of images.
            #expect(storeS3ReadmeImagesCalls.value == 1)
        }
    }

    @Test func ingest_storeS3Readme_error() async throws {
        // Test caching behaviour in case the storeS3Readme call fails
        try await withApp { app in
            // setup
            let pkg = Package(url: "https://github.com/foo/bar".url, processingStage: .reconciliation)
            try await pkg.save(on: app.db)
            let storeCalls = QueueIsolated(0)

            do { // first ingestion, no readme has been saved
                try await withDependencies {
                    $0.date.now = .now
                    $0.github.fetchLicense = { @Sendable _, _ in nil }
                    $0.github.fetchMetadata = { @Sendable owner, repository in .mock(owner: owner, repository: repository) }
                    $0.github.fetchReadme = { @Sendable _, _ in
                        return .init(etag: "etag1",
                                     html: "readme html 1",
                                     htmlUrl: "readme url",
                                     imagesToCache: [])
                    }
                    $0.s3.storeReadme = { owner, repo, html throws(S3Readme.Error) in
                        storeCalls.increment()
                        throw .storeReadmeFailed
                    }
                } operation: {
                    // MUT
                    try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(1))
                }

                // validate
                #expect(try await Repository.query(on: app.db).count() == 1)
                let repo = try #require(await Repository.query(on: app.db).first())
                #expect(storeCalls.value == 1)
                // Ensure an error is recorded
                #expect(repo.s3Readme?.isError ?? false)
            }
        }
    }

    @Test func issue_761_no_license() async throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/761
        try await withDependencies {
            // use live fetch request for fetchLicense, whose behaviour we want to test ...
            $0.github.fetchLicense = GithubClient.liveValue.fetchLicense
            // use mock for metadata request which we're not interested in ...
            $0.github.fetchMetadata = { @Sendable _, _ in .init() }
            $0.github.fetchReadme = { @Sendable _, _ in nil }
            $0.github.token = { "token" }
            $0.httpClient.get = { @Sendable url, _ in
                if url.hasSuffix("/license") {
                    return .notFound
                } else {
                    Issue.record("unexpected url \(url)")
                    struct TestError: Error { }
                    throw TestError()
                }
            }
        } operation: {
            try await withApp { app in
                // setup
                let pkg = Package(url: "https://github.com/foo/1")
                try await pkg.save(on: app.db)

                // MUT
                let (_, license, _) = try await Ingestion.fetchMetadata(package: pkg, owner: "foo", repository: "1")

                // validate
                #expect(license == nil)
            }
        }
    }

    @Test func migration076_updateRepositoryResetReadmes() async throws {
        try await withApp { app in
            let package = Package(url: "https://example.com/owner/repo")
            try await package.save(on: app.db)
            let repository = try Repository(package: package, s3Readme: .cached(s3ObjectUrl: "object-url", githubEtag: "etag"))
            try await repository.save(on: app.db)

            // Validation that the etag exists
            let preMigrationFetchedRepo = try #require(try await Repository.query(on: app.db).first())
            #expect(preMigrationFetchedRepo.s3Readme == .cached(s3ObjectUrl: "object-url", githubEtag: "etag"))

            // MUT
            try await UpdateRepositoryResetReadmes().prepare(on: app.db)

            // Validation
            let postMigrationFetchedRepo = try #require(try await Repository.query(on: app.db).first())
            #expect(postMigrationFetchedRepo.s3Readme == .cached(s3ObjectUrl: "object-url", githubEtag: ""))
        }
    }

    @Test func getFork() async throws {
        try await withApp { app in
            try await Package(id: .id0, url: "https://github.com/foo/parent.git".url, processingStage: .analysis).save(on: app.db)
            try await Package(url: "https://github.com/bar/forked.git", processingStage: .analysis).save(on: app.db)

            // test lookup when package is in the index
            let fork = await Ingestion.getFork(on: app.db, parent: .init(url: "https://github.com/foo/parent.git"))
            #expect(fork == .parentId(id: .id0, fallbackURL: "https://github.com/foo/parent.git"))

            // test lookup when package is in the index but with different case in URL
            let fork2 = await Ingestion.getFork(on: app.db, parent: .init(url: "https://github.com/Foo/Parent.git"))
            #expect(fork2 == .parentId(id: .id0, fallbackURL: "https://github.com/Foo/Parent.git"))

            // test whem metadata repo url doesn't have `.git` at end
            let fork3 = await Ingestion.getFork(on: app.db, parent: .init(url: "https://github.com/Foo/Parent"))
            #expect(fork3 == .parentId(id: .id0, fallbackURL: "https://github.com/Foo/Parent.git"))

            // test lookup when package is not in the index
            let fork4 = await Ingestion.getFork(on: app.db, parent: .init(url: "https://github.com/some/other.git"))
            #expect(fork4 == .parentURL("https://github.com/some/other.git"))

            // test lookup when parent url is nil
            let fork5 = await Ingestion.getFork(on: app.db, parent: nil)
            #expect(fork5 == nil)
        }
    }
}


private extension String {
    static func packageDump(name: String) -> Self {
        #"""
            {
              "name": "\#(name)",
              "products": [
                {
                  "name": "p1",
                  "targets": [],
                  "type": {
                    "executable": null
                  }
                }
              ],
              "targets": []
            }
            """#
    }
}
