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
import PackageCollectionsSigning
import SnapshotTesting
import Testing
import XCTVapor


extension AllTests.ApiTests {

    @Test func version() async throws {
        try await withApp { app in
            try await app.test(.GET, "api/version", afterResponse: { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode(API.Version.self) == API.Version(version: "Unknown"))
            })
        }
                           }

    @Test func search_noQuery() async throws {
        try await withDependencies {
            $0.environment.apiSigningKey = { "secret" }
            $0.httpClient.postPlausibleEvent = App.HTTPClient.noop
        } operation: {
            try await withApp { app in
                // MUT
                try await app.test(.GET, "api/search",
                                   headers: .bearerApplicationJSON(try .apiToken(secretKey: "secret", tier: .tier1)),
                                   afterResponse: { res async throws in
                    #expect(res.status == .ok)
                    #expect(try res.content.decode(Search.Response.self) == .init(hasMoreResults: false,
                                                                                  searchTerm: "",
                                                                                  searchFilters: [],
                                                                                  results: []))
                })
            }
        }
    }

    @Test func search_basic_param() async throws {
        let event = App.ActorIsolated<TestEvent?>(nil)
        try await withDependencies {
            $0.environment.apiSigningKey = { "secret" }
            $0.httpClient.postPlausibleEvent = { @Sendable kind, path, _ in
                await event.setValue(.init(kind: kind, path: path))
            }
        } operation: {
            try await withApp { app in
                let p1 = Package(id: .id0, url: "1")
                try await p1.save(on: app.db)
                let p2 = Package(id: .id1, url: "2")
                try await p2.save(on: app.db)
                try await Repository(package: p1,
                                     defaultBranch: "main",
                                     summary: "some package").save(on: app.db)
                try await Repository(package: p2,
                                     defaultBranch: "main",
                                     lastCommitDate: .t0,
                                     name: "name 2",
                                     owner: "owner 2",
                                     stars: 1234,
                                     summary: "foo bar package").save(on: app.db)
                try await Version(package: p1, packageName: "Foo", reference: .branch("main")).save(on: app.db)
                try await Version(package: p2, packageName: "Bar", reference: .branch("main")).save(on: app.db)
                try await Search.refresh(on: app.db)

                // MUT
                try await app.test(.GET, "api/search?query=foo%20bar",
                                   headers: .bearerApplicationJSON(try .apiToken(secretKey: "secret", tier: .tier1)),
                                   afterResponse: { res async throws in
                    // validation
                    #expect(res.status == .ok)
                    #expect(
                        try res.content.decode(Search.Response.self) == .init(hasMoreResults: false,
                                                                              searchTerm: "foo bar",
                                                                              searchFilters: [],
                                                                              results: [
                                                                                .package(
                                                                                    .init(packageId: .id1,
                                                                                          packageName: "Bar",
                                                                                          packageURL: "/owner%202/name%202",
                                                                                          repositoryName: "name 2",
                                                                                          repositoryOwner: "owner 2",
                                                                                          stars: 1234,
                                                                                          lastActivityAt: .t0,
                                                                                          summary: "foo bar package",
                                                                                          keywords: [],
                                                                                          hasDocs: false)!
                                                                                )
                                                                              ])
                    )
                })

                // ensure API event has been reported
                await event.withValue {
                    #expect($0 == .some(.init(kind: .pageview, path: .search)))
                }
            }
        }
    }

    @Test func search_unauthenticated() async throws {
        try await withDependencies {
            $0.environment.apiSigningKey = { "secret" }
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                // MUT
                try await app.test(.GET, "api/search?query=test") { res async in
                    // validation
                    #expect(res.status == .unauthorized)
                }
            }
        }
    }

    @Test func buildReportDecoder() throws {
        // Ensure we can decode the date format the builder sends
        let body = """
            {"buildCommand":"cmd","buildDate":0,"buildId":"711d4034-c6f3-47de-a3c9-32a3b70cb9bc","logUrl":"log url","platform":"ios","status":"ok","swiftVersion":{"major":5,"minor":10,"patch":0}}
            """
        #expect(
            (try API.BuildController.buildReportDecoder.decode(API.PostBuildReportDTO.self, from: .init(string: body))).buildDate == .t0
        )
    }

    @Test func post_buildReport() async throws {
        try await withDependencies {
            $0.environment.builderToken = { "secr3t" }
        } operation: {
            try await withApp { app in
                // setup
                let p = try await savePackage(on: app.db, "1")
                let v = try Version(package: p, latest: .defaultBranch)
                try await v.save(on: app.db)
                let versionId = try v.requireID()

                do {  // MUT - initial insert
                    let dto: API.PostBuildReportDTO = .init(
                        buildCommand: "xcodebuild -scheme Foo",
                        buildDate: .t0,
                        buildDuration: 123.4,
                        buildErrors: .init(numSwift6Errors: 42),
                        builderVersion: "1.2.3",
                        buildId: .id0,
                        commitHash: "sha",
                        jobUrl: "https://example.com/jobs/1",
                        logUrl: "log url",
                        platform: .macosXcodebuild,
                        productDependencies: [.init(identity: "identity", name: "name", url: "url", dependencies: [])],
                        resolvedDependencies: [.init(packageName: "packageName", repositoryURL: "repositoryURL")],
                        runnerId: "some-runner",
                        status: .failed,
                        swiftVersion: .init(5, 2, 0)
                    )
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .secondsSince1970
                    let body: ByteBuffer = .init(data: try encoder.encode(dto))
                    try await app.test(
                        .POST,
                        "api/versions/\(versionId)/build-report",
                        headers: .bearerApplicationJSON("secr3t"),
                        body: body,
                        afterResponse: { res async throws in
                            // validation
                            #expect(res.status == .noContent)
                            let builds = try await Build.query(on: app.db).all()
                            #expect(builds.count == 1)
                            let b = try builds.first.unwrap()
                            #expect(b.id == .id0)
                            #expect(b.buildCommand == "xcodebuild -scheme Foo")
                            #expect(b.buildDate == .t0)
                            #expect(b.buildDuration == 123.4)
                            #expect(b.buildErrors == .init(numSwift6Errors: 42))
                            #expect(b.builderVersion == "1.2.3")
                            #expect(b.commitHash == "sha")
                            #expect(b.jobUrl == "https://example.com/jobs/1")
                            #expect(b.logUrl == "log url")
                            #expect(b.platform == .macosXcodebuild)
                            #expect(b.runnerId == "some-runner")
                            #expect(b.status == .failed)
                            #expect(b.swiftVersion == .init(5, 2, 0))
                            let v = try await Version.find(versionId, on: app.db).unwrap(or: Abort(.notFound))
                            #expect(v.productDependencies == [.init(identity: "identity",
                                                                    name: "name",
                                                                    url: "url",
                                                                    dependencies: [])])
                            #expect(v.resolvedDependencies == [.init(packageName: "packageName",
                                                                     repositoryURL: "repositoryURL")])
                            // build failed, hence no package platform compatibility yet
                            let p = try #require(try await Package.find(p.id, on: app.db))
                            #expect(p.platformCompatibility == [])
                        })
                }

                do {  // MUT - update of the same record
                    let dto: API.PostBuildReportDTO = .init(
                        buildId: .id0,
                        platform: .macosXcodebuild,
                        resolvedDependencies: [.init(packageName: "foo",
                                                     repositoryURL: "http://foo/bar")],
                        status: .ok,
                        swiftVersion: .init(5, 2, 0)
                    )
                    let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
                    try await app.test(
                        .POST,
                        "api/versions/\(versionId)/build-report",
                        headers: .bearerApplicationJSON("secr3t"),
                        body: body,
                        afterResponse: { res async throws in
                            // validation
                            #expect(res.status == .noContent)
                            let builds = try await Build.query(on: app.db).all()
                            #expect(builds.count == 1)
                            let b = try builds.first.unwrap()
                            #expect(b.id == .id0)
                            #expect(b.platform == .macosXcodebuild)
                            #expect(b.status == .ok)
                            #expect(b.swiftVersion == .init(5, 2, 0))
                            let v = try await Version.find(versionId, on: app.db).unwrap(or: Abort(.notFound))
                            #expect(v.resolvedDependencies == [.init(packageName: "foo",
                                                                     repositoryURL: "http://foo/bar")])
                            // build ok now -> package is macos compatible
                            let p = try #require(try await Package.find(p.id, on: app.db))
                            #expect(p.platformCompatibility == [.macOS])
                        })
                }

                do {  // MUT - add another build to test Package.platformCompatibility
                    let dto: API.PostBuildReportDTO = .init(
                        buildId: .id1,
                        platform: .iOS,
                        resolvedDependencies: [.init(packageName: "foo",
                                                     repositoryURL: "http://foo/bar")],
                        status: .ok,
                        swiftVersion: .init(5, 2, 0)
                    )
                    let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
                    try await app.test(
                        .POST,
                        "api/versions/\(versionId)/build-report",
                        headers: .bearerApplicationJSON("secr3t"),
                        body: body,
                        afterResponse: { res async throws in
                            // validation
                            let builds = try await Build.query(on: app.db).all()
                            #expect(Set(builds.map(\.id)) == Set([.id0, .id1]))
                            // additional ios build ok -> package is also ios compatible
                            let p = try #require(try await Package.find(p.id, on: app.db))
                            #expect(p.platformCompatibility == [.iOS, .macOS])
                        })
                }
            }
        }
    }

    @Test func post_buildReport_conflict() async throws {
        // Test behaviour when reporting back with a different build id for the same build pair. This would not
        // happen in normal behaviour but it _is_ something we rely on when running the builder tests. They
        // trigger builds not via trigger commands that prepares a build record before triggering, resolving
        // potential conflicts ahead of time. Instead the build is simply triggered and reported back with a
        // configured build id.
        try await withDependencies {
            $0.environment.builderToken = { "secr3t" }
        } operation: {
            try await withApp { app in
                // setup
                let p = try await savePackage(on: app.db, "1")
                let v = try Version(package: p, latest: .defaultBranch)
                try await v.save(on: app.db)
                let versionId = try v.requireID()
                try await Build(id: .id0, version: v, platform: .iOS, status: .failed, swiftVersion: .latest).save(on: app.db)

                let dto: API.PostBuildReportDTO = .init(
                    buildId: .id1,
                    platform: .iOS,
                    status: .ok,
                    swiftVersion: .latest
                )
                let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
                try await app.test(
                    .POST,
                    "api/versions/\(versionId)/build-report",
                    headers: .bearerApplicationJSON("secr3t"),
                    body: body,
                    afterResponse: { res in
                        // validation
                        #expect(res.status == .noContent)
                        let builds = try await Build.query(on: app.db).all()
                        #expect(builds.count == 1)
                        let b = try builds.first.unwrap()
                        #expect(b.id == .id1)
                        #expect(b.platform == .iOS)
                        #expect(b.status == .ok)
                        #expect(b.swiftVersion == .latest)
                    })
            }
        }
    }

    @Test func post_buildReport_infrastructureError() async throws {
        try await withDependencies {
            $0.environment.builderToken = { "secr3t" }
        } operation: {
            try await withApp { app in
                // setup
                let p = try await savePackage(on: app.db, "1")
                let v = try Version(package: p)
                try await v.save(on: app.db)
                let versionId = try #require(v.id)

                let dto: API.PostBuildReportDTO = .init(
                    buildCommand: "xcodebuild -scheme Foo",
                    buildId: .id0,
                    jobUrl: "https://example.com/jobs/1",
                    logUrl: "log url",
                    platform: .macosXcodebuild,
                    status: .infrastructureError,
                    swiftVersion: .init(5, 2, 0))
                let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
                try await app.test(
                    .POST,
                    "api/versions/\(versionId)/build-report",
                    headers: .bearerApplicationJSON("secr3t"),
                    body: body,
                    afterResponse: { res async throws in
                        // validation
                        #expect(res.status == .noContent)
                        let builds = try await Build.query(on: app.db).all()
                        #expect(builds.count == 1)
                        let b = try builds.first.unwrap()
                        #expect(b.status == .infrastructureError)
                    })
            }
        }
    }

    @Test func post_buildReport_unauthenticated() async throws {
        // Ensure unauthenticated access raises a 401
        try await withDependencies {
            $0.environment.builderToken = { "secr3t" }
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                // setup
                let p = try await savePackage(on: app.db, "1")
                let v = try Version(package: p)
                try await v.save(on: app.db)
                let versionId = try #require(v.id)
                let dto: API.PostBuildReportDTO = .init(buildId: .id0,
                                                        platform: .macosXcodebuild,
                                                        status: .ok,
                                                        swiftVersion: .init(5, 2, 0))
                let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
                let db = app.db

                // MUT - no auth header
                try await app.test(
                    .POST,
                    "api/versions/\(versionId)/build-report",
                    headers: .applicationJSON,
                    body: body,
                    afterResponse: { res async throws in
                        // validation
                        #expect(res.status == .unauthorized)
                        #expect(try await Build.query(on: db).count() == 0)
                    }
                )

                // MUT - wrong token
                try await app.test(
                    .POST,
                    "api/versions/\(versionId)/build-report",
                    headers: .bearerApplicationJSON("wrong"),
                    body: body,
                    afterResponse: { res async throws in
                        // validation
                        #expect(res.status == .unauthorized)
                        #expect(try await Build.query(on: db).count() == 0)
                    }
                )

                // MUT - without server token
                try await withDependencies {
                    $0.environment.builderToken = { nil }
                } operation: {
                    try await app.test(
                        .POST,
                        "api/versions/\(versionId)/build-report",
                        headers: .bearerApplicationJSON("secr3t"),
                        body: body,
                        afterResponse: { res async throws in
                            // validation
                            #expect(res.status == .unauthorized)
                            #expect(try await Build.query(on: db).count() == 0)
                        }
                    )
                }
            }
        }
    }

    @Test func post_buildReport_large() async throws {
        // Ensure we can handle large build reports
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2825
        try await withDependencies {
            $0.environment.builderToken = { "secr3t" }
        } operation: {
            try await withApp { app in
                // setup
                let p = try await savePackage(on: app.db, "1")
                let v = try Version(package: p, latest: .defaultBranch)
                try await v.save(on: app.db)
                let versionId = try v.requireID()

                // MUT
                let data = try fixtureData(for: "large-build-report.json")
                #expect(data.count > 16_000, "was: \(data.count) bytes")
                let body: ByteBuffer = .init(data: data)
                let outOfTheWayPort = 12_345
                try await app.testable(method: .running(port: outOfTheWayPort)).test(
                    .POST,
                    "api/versions/\(versionId)/build-report",
                    headers: .bearerApplicationJSON("secr3t"),
                    body: body,
                    afterResponse: { res async in
                        // validation
                        #expect(res.status == .noContent)
                    })
            }
        }
    }

    @Test func post_buildReport_package_updatedAt() async throws {
        // Ensure we don't change packages.updatedAt when receiving a build report.
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/3290#issuecomment-2293101104
        try await withDependencies {
            $0.environment.builderToken = { "secr3t" }
        } operation: {
            try await withApp { app in
                // setup
                let p = try await savePackage(on: app.db, "1")
                let originalPackageUpdate = try #require(p.updatedAt)
                let v = try Version(package: p, latest: .defaultBranch)
                try await v.save(on: app.db)
                let versionId = try v.requireID()
                // Sleep for 1ms to ensure we can detect a difference between update times.
                try await Task.sleep(nanoseconds: UInt64(1e6))

                // MUT
                let dto: API.PostBuildReportDTO = .init(
                    buildCommand: "xcodebuild -scheme Foo",
                    buildDate: .t0,
                    buildDuration: 123.4,
                    buildErrors: .init(numSwift6Errors: 42),
                    builderVersion: "1.2.3",
                    buildId: .id0,
                    commitHash: "sha",
                    jobUrl: "https://example.com/jobs/1",
                    logUrl: "log url",
                    platform: .macosXcodebuild,
                    productDependencies: [.init(identity: "identity", name: "name", url: "url", dependencies: [])],
                    resolvedDependencies: [.init(packageName: "packageName", repositoryURL: "repositoryURL")],
                    runnerId: "some-runner",
                    status: .failed,
                    swiftVersion: .init(5, 2, 0)
                )
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .secondsSince1970
                let body: ByteBuffer = .init(data: try encoder.encode(dto))
                try await app.test(
                    .POST,
                    "api/versions/\(versionId)/build-report",
                    headers: .bearerApplicationJSON("secr3t"),
                    body: body,
                    afterResponse: { res async throws in
                        // validation
                        let p = try #require(await Package.find(p.id, on: app.db))
#if os(Linux)
                        if p.updatedAt == originalPackageUpdate {
                            logWarning()
                            // When this triggers, remove Task.sleep above and the validtion below until // TEMPORARY - END
                            // and replace with original assert:
                            //      XCTAssertEqual(p.updatedAt, originalPackageUpdate)
                        }
#endif
                        let updatedAt = try #require(p.updatedAt)
                        // Comparing the dates directly fails due to tiny rounding differences with the new swift-foundation types on Linux
                        // E.g.
                        // 1724071056.5824609
                        // 1724071056.5824614
                        // By testing only to accuracy 10e-5 and delaying by 10e-3 we ensure we properly detect if the value was changed.
                        #expect(fabs(updatedAt.timeIntervalSince1970 - originalPackageUpdate.timeIntervalSince1970) <= 10e-5)
                        // TEMPORARY - END
                    })
            }
        }
    }

    @Test func post_docReport() async throws {
        try await withDependencies {
            $0.environment.builderToken = { "secr3t" }
        } operation: {
            try await withApp { app in
                // setup
                let p = try await savePackage(on: app.db, "1")
                let v = try Version(package: p, latest: .defaultBranch)
                try await v.save(on: app.db)
                let b = try Build(version: v, platform: .iOS, status: .ok, swiftVersion: .v3)
                try await b.save(on: app.db)
                let buildId = try b.requireID()

                do {  // MUT - initial insert
                    let dto: API.PostDocReportDTO = .init(error: "too large",
                                                          fileCount: 70_000,
                                                          linkablePathsCount: 137,
                                                          logUrl: "log url",
                                                          mbSize: 900,
                                                          status: .skipped)
                    let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
                    try await app.test(
                        .POST,
                        "api/builds/\(buildId)/doc-report",
                        headers: .bearerApplicationJSON("secr3t"),
                        body: body,
                        afterResponse: { res in
                            // validation
                            #expect(res.status == .noContent)
                            let docUploads = try await DocUpload.query(on: app.db).all()
                            #expect(docUploads.count == 1)
                            let d = try docUploads.first.unwrap()
                            #expect(d.error == "too large")
                            #expect(d.fileCount == 70_000)
                            #expect(d.linkablePathsCount == 137)
                            #expect(d.logUrl == "log url")
                            #expect(d.mbSize == 900)
                            #expect(d.status == .skipped)
                        })
                }

                do {  // send report again to same buildId
                    let dto: API.PostDocReportDTO = .init(
                        docArchives: [.init(name: "foo", title: "Foo")],
                        status: .ok
                    )
                    let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
                    try await app.test(
                        .POST,
                        "api/builds/\(buildId)/doc-report",
                        headers: .bearerApplicationJSON("secr3t"),
                        body: body,
                        afterResponse: { res in
                            // validation
                            #expect(res.status == .noContent)
                            let docUploads = try await DocUpload.query(on: app.db).all()
                            #expect(docUploads.count == 1)
                            let d = try docUploads.first.unwrap()
                            #expect(d.status == .ok)
                            try await d.$build.load(on: app.db)
                            try await d.build.$version.load(on: app.db)
                            #expect(d.build.version.docArchives == [.init(name: "foo", title: "Foo")])
                        })
                }

                do {  // make sure a .pending report without docArchives does not reset them
                    let dto: API.PostDocReportDTO = .init(docArchives: nil, status: .pending)
                    let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
                    try await app.test(
                        .POST,
                        "api/builds/\(buildId)/doc-report",
                        headers: .bearerApplicationJSON("secr3t"),
                        body: body,
                        afterResponse: { res in
                            // validation
                            #expect(res.status == .noContent)
                            let docUploads = try await DocUpload.query(on: app.db).all()
                            #expect(docUploads.count == 1)
                            let d = try docUploads.first.unwrap()
                            #expect(d.status == .pending)
                            try await d.$build.load(on: app.db)
                            try await d.build.$version.load(on: app.db)
                            #expect(d.build.version.docArchives == [.init(name: "foo", title: "Foo")])
                        })
                }
            }
        }
    }

    @Test func post_docReport_override() async throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2280
        // Ensure a subsequent doc report on a different build does not trip over a UK violation
        try await withDependencies {
            $0.environment.builderToken = { "secr3t" }
        } operation: {
            try await withApp { app in
                // setup
                let p = try await savePackage(on: app.db, "1")
                let v = try Version(package: p, latest: .defaultBranch)
                try await v.save(on: app.db)
                let b1 = try Build(id: .id0, version: v, platform: .linux, status: .ok, swiftVersion: .v3)
                try await b1.save(on: app.db)
                let b2 = try Build(id: .id1, version: v, platform: .macosSpm, status: .ok, swiftVersion: .v3)
                try await b2.save(on: app.db)

                do {  // initial insert
                    let dto = API.PostDocReportDTO(status: .pending)
                    try await app.test(
                        .POST,
                        "api/builds/\(b1.id!)/doc-report",
                        headers: .bearerApplicationJSON("secr3t"),
                        body: .init(data: try JSONEncoder().encode(dto)),
                        afterResponse: { res in
                            // validation
                            #expect(res.status == .noContent)
                            let docUploads = try await DocUpload.query(on: app.db).all()
                            #expect(docUploads.count == 1)
                            let d = try await DocUpload.query(on: app.db).first()
                            #expect(d?.$build.id == b1.id)
                            #expect(d?.status == .pending)
                        })
                }

                do {  // MUT - override
                    let dto = API.PostDocReportDTO(status: .ok)
                    try await app.test(
                        .POST,
                        "api/builds/\(b2.id!)/doc-report",
                        headers: .bearerApplicationJSON("secr3t"),
                        body: .init(data: try JSONEncoder().encode(dto)),
                        afterResponse: { res in
                            // validation
                            #expect(res.status == .noContent)
                            let docUploads = try await DocUpload.query(on: app.db).all()
                            #expect(docUploads.count == 1)
                            let d = try await DocUpload.query(on: app.db).first()
                            #expect(d?.$build.id == b2.id)
                            #expect(d?.status == .ok)
                        })
                }
            }
        }
    }

    @Test func post_docReport_non_existing_build() async throws {
        try await withDependencies {
            $0.environment.builderToken = { "secr3t" }
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                // setup
                let nonExistingBuildId = UUID()

                do {  // send report to non-existing buildId
                    let dto: API.PostDocReportDTO = .init(status: .ok)
                    let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
                    try await app.test(
                        .POST,
                        "api/builds/\(nonExistingBuildId)/doc-report",
                        headers: .bearerApplicationJSON("secr3t"),
                        body: body,
                        afterResponse: { res in
                            // validation
                            #expect(res.status == .notFound)
                            let docUploads = try await DocUpload.query(on: app.db).all()
                            #expect(docUploads.count == 0)
                        })
                }
            }
        }
    }

    @Test func post_docReport_unauthenticated() async throws {
        try await withDependencies {
            $0.environment.builderToken = { "secr3t" }
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                // setup
                let p = try await savePackage(on: app.db, "1")
                let v = try Version(package: p, latest: .defaultBranch)
                try await v.save(on: app.db)
                let b = try Build(version: v, platform: .iOS, status: .ok, swiftVersion: .v3)
                try await b.save(on: app.db)
                let buildId = try b.requireID()
                let dto: API.PostDocReportDTO = .init(status: .ok)
                let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))

                // MUT - no auth header
                try await app.test(
                    .POST,
                    "api/builds/\(buildId)/doc-report",
                    headers: .applicationJSON,
                    body: body,
                    afterResponse: { res async throws in
                        // validation
                        #expect(res.status == .unauthorized)
                        #expect(try await DocUpload.query(on: app.db).count() == 0)
                    }
                )

                // MUT - wrong token
                try await app.test(
                    .POST,
                    "api/builds/\(buildId)/doc-report",
                    headers: .bearerApplicationJSON("wrong"),
                    body: body,
                    afterResponse: { res async throws in
                        // validation
                        #expect(res.status == .unauthorized)
                        #expect(try await DocUpload.query(on: app.db).count() == 0)
                    }
                )

                // MUT - without server token
                try await withDependencies {
                    $0.environment.builderToken = { nil }
                } operation: {
                    try await app.test(
                        .POST,
                        "api/builds/\(buildId)/doc-report",
                        headers: .bearerApplicationJSON("secr3t"),
                        body: body,
                        afterResponse: { res async throws in
                            // validation
                            #expect(res.status == .unauthorized)
                            #expect(try await DocUpload.query(on: app.db).count() == 0)
                        }
                    )
                }
            }
        }
    }

    @Test func BadgeRoute_query() async throws {
        try await withApp { app in
            // setup
            let p = try await savePackage(on: app.db, "1")
            let v = try Version(package: p, latest: .release, reference: .tag(.init(1, 2, 3)))
            try await v.save(on: app.db)
            try await Repository(package: p,
                                 defaultBranch: "main",
                                 license: .mit,
                                 name: "repo",
                                 owner: "owner").save(on: app.db)
            // add builds
            try await Build(version: v, platform: .linux, status: .ok, swiftVersion: .v3)
                .save(on: app.db)
            try await Build(version: v, platform: .macosSpm, status: .ok, swiftVersion: .v2)
                .save(on: app.db)
            do { // save decoy
                let p = try await savePackage(on: app.db, "2")
                let v = try Version(package: p, latest: .release, reference: .tag(.init(2, 0, 0)))
                try await v.save(on: app.db)
                try await Repository(package: p,
                                     defaultBranch: "main",
                                     license: .mit,
                                     name: "decoy",
                                     owner: "owner").save(on: app.db)
                try await Build(version: v, platform: .iOS, status: .ok, swiftVersion: .v1)
                    .save(on: app.db)
            }

            // MUT
            let sb = try await API.PackageController.BadgeRoute.query(on: app.db, owner: "owner", repository: "repo")

            // validate
            #expect(sb.builds.sorted() == [
                .init(.v2, .macosSpm, .ok),
                .init(.v3, .linux, .ok)
            ])
        }
    }

    @Test func get_badge() async throws {
        // sas 2024-12-20: Badges are not reporting plausbile events, because they triggered way too many events. (This is an old changes, just adding this comment today as I'm removing the old, commented out test remnants we still had in place.)
        try await withApp { app in
            // setup
            let owner = "owner"
            let repo = "repo"
            let p = try await savePackage(on: app.db, "1")
            let v = try Version(package: p, latest: .release, reference: .tag(1, 2, 3))
            try await v.save(on: app.db)
            try await Repository(package: p,
                                 defaultBranch: "main",
                                 license: .mit,
                                 name: repo,
                                 owner: owner).save(on: app.db)
            // add builds
            try await Build(version: v, platform: .linux, status: .ok, swiftVersion: .v2)
                .save(on: app.db)
            try await Build(version: v, platform: .macosXcodebuild, status: .ok, swiftVersion: .v1)
                .save(on: app.db)

            // MUT - swift versions
            try await app.test(
                .GET,
                "api/packages/\(owner)/\(repo)/badge?type=swift-versions",
                afterResponse: { res async throws in
                    // validation
                    #expect(res.status == .ok)

                    let badge = try res.content.decode(Badge.self)
                    #expect(badge.schemaVersion == 1)
                    #expect(badge.label == "Swift")
                    #expect(badge.message == "5.9 | 5.8")
                    #expect(badge.isError == false)
                    #expect(badge.color == "blue")
                    #expect(badge.cacheSeconds == 6*3600)
                    #expect(badge.logoSvg != nil)
                })

            // MUT - platforms
            try await app.test(
                .GET,
                "api/packages/\(owner)/\(repo)/badge?type=platforms",
                afterResponse: { res async throws in
                    // validation
                    #expect(res.status == .ok)

                    let badge = try res.content.decode(Badge.self)
                    #expect(badge.schemaVersion == 1)
                    #expect(badge.label == "Platforms")
                    #expect(badge.message == "macOS | Linux")
                    #expect(badge.isError == false)
                    #expect(badge.color == "blue")
                    #expect(badge.cacheSeconds == 6*3600)
                    #expect(badge.logoSvg != nil)
                })
        }
    }

    @Test(.disabled(if: !isRunningInCI() && EnvironmentClient.liveValue.collectionSigningPrivateKey() == nil,
                    "Skip test for local user due to unset COLLECTION_SIGNING_PRIVATE_KEY env variable"))
    func package_collections_owner() async throws {
        let event = App.ActorIsolated<TestEvent?>(nil)
        try await withDependencies {
            $0.date.now = .t0
            $0.environment.apiSigningKey = { "secret" }
            $0.environment.collectionSigningCertificateChain = EnvironmentClient.liveValue.collectionSigningCertificateChain
            $0.environment.collectionSigningPrivateKey = EnvironmentClient.liveValue.collectionSigningPrivateKey
            $0.httpClient.postPlausibleEvent = { @Sendable kind, path, _ in
                await event.setValue(.init(kind: kind, path: path))
            }
        } operation: {
            try await withApp { app in
                // setup
                let p1 = Package(id: .id1, url: "1")
                try await p1.save(on: app.db)
                try await Repository(package: p1,
                                     defaultBranch: "main",
                                     name: "name 1",
                                     owner: "foo",
                                     summary: "foo bar package").save(on: app.db)
                let v = try Version(package: p1,
                                    latest: .release,
                                    packageName: "Foo",
                                    reference: .tag(1, 2, 3),
                                    toolsVersion: "5.0")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "lib")
                    .save(on: app.db)

                do {  // MUT
                    let body: ByteBuffer = .init(string: """
                {
                  "revision": 3,
                  "authorName": "author",
                  "keywords": [
                    "a",
                    "b"
                  ],
                  "selection": {
                    "author": {
                      "_0": "foo"
                    }
                  },
                  "collectionName": "my collection",
                  "overview": "my overview"
                }
                """)

                    try await app.test(.POST, "api/package-collections",
                                       headers: .bearerApplicationJSON(try .apiToken(secretKey: "secret", tier: .tier3)),
                                       body: body,
                                       afterResponse: { res async throws in
                        // validation
                        #expect(res.status == .ok)
                        let container = try res.content.decode(SignedCollection.self)
                        #expect(!container.signature.signature.isEmpty)
                        // more details are tested in PackageCollectionTests
                        #expect(container.collection.name == "my collection")
                    })
                }

                // ensure API event has been reported
                await event.withValue {
                    #expect($0 == .some(.init(kind: .pageview, path: .packageCollections)))
                }
            }
        }
    }

    @Test(.disabled(if: !isRunningInCI() && EnvironmentClient.liveValue.collectionSigningPrivateKey() == nil,
                    "Skip test for local user due to unset COLLECTION_SIGNING_PRIVATE_KEY env variable"))
    func package_collections_packageURLs() async throws {
        let refDate = Date(timeIntervalSince1970: 0)
        try await withDependencies {
            $0.date.now = refDate
            $0.environment.apiSigningKey = { "secret" }
            $0.environment.collectionSigningCertificateChain = EnvironmentClient.liveValue.collectionSigningCertificateChain
            $0.environment.collectionSigningPrivateKey = EnvironmentClient.liveValue.collectionSigningPrivateKey
            $0.httpClient.postPlausibleEvent = App.HTTPClient.noop
        } operation: {
            try await withApp { app in
                // setup
                let p1 = Package(id: UUID(uuidString: "442cf59f-0135-4d08-be00-bc9a7cebabd3")!,
                                 url: "1")
                try await p1.save(on: app.db)
                let p2 = Package(id: UUID(uuidString: "4e256250-d1ea-4cdd-9fe9-0fc5dce17a80")!,
                                 url: "2")
                try await p2.save(on: app.db)
                try await Repository(package: p1,
                                     defaultBranch: "main",
                                     summary: "some package").save(on: app.db)
                try await Repository(package: p2,
                                     defaultBranch: "main",
                                     name: "name 2",
                                     owner: "foo",
                                     summary: "foo bar package").save(on: app.db)
                do {
                    let v = try Version(package: p1,
                                        latest: .release,
                                        packageName: "Foo",
                                        reference: .tag(1, 2, 3),
                                        toolsVersion: "5.3")
                    try await v.save(on: app.db)
                    try await Product(version: v, type: .library(.automatic), name: "p1")
                        .save(on: app.db)
                }
                do {
                    let v = try Version(package: p2,
                                        latest: .release,
                                        packageName: "Bar",
                                        reference: .tag(2, 0, 0),
                                        toolsVersion: "5.4")
                    try await v.save(on: app.db)
                    try await Product(version: v, type: .library(.automatic), name: "p2")
                        .save(on: app.db)
                }

                do {  // MUT
                    let body: ByteBuffer = .init(string: """
                {
                  "revision": 3,
                  "authorName": "author",
                  "keywords": [
                    "a",
                    "b"
                  ],
                  "selection": {
                    "packageURLs": {
                      "_0": [
                        "1"
                      ]
                    }
                  },
                  "collectionName": "my collection",
                  "overview": "my overview"
                }
                """)

                    try await app.test(.POST,
                                       "api/package-collections",
                                       headers: .bearerApplicationJSON((try .apiToken(secretKey: "secret", tier: .tier3))),
                                       body: body,
                                       afterResponse: { res async throws in
                        // validation
                        #expect(res.status == .ok)
                        let pkgColl = try res.content.decode(PackageCollection.self)
                        assertSnapshot(of: pkgColl, as: .dump)
                    })
                }
            }
        }
    }

    @Test func package_collections_packageURLs_limit() async throws {
        try await withDependencies {
            $0.environment.apiSigningKey = { "secret" }
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                let dto = API.PostPackageCollectionDTO(
                    // request 21 urls - this should raise a 400
                    selection: .packageURLs((0...20).map(String.init))
                )
                let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))

                try await app.test(.POST,
                                   "api/package-collections",
                                   headers: .bearerApplicationJSON((try .apiToken(secretKey: "secret", tier: .tier3))),
                                   body: body,
                                   afterResponse: { res async in
                    // validation
                    #expect(res.status == .badRequest)
                })
            }
        }
    }

    @Test func package_collections_unauthorized() async throws {
        try await withDependencies {
            $0.environment.apiSigningKey = { "secret" }
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                // MUT - happy path
                let body: ByteBuffer = .init(string: """
                {
                  "revision": 3,
                  "authorName": "author",
                  "keywords": [
                    "a",
                    "b"
                  ],
                  "selection": {
                    "author": {
                      "_0": "foo"
                    }
                  },
                  "collectionName": "my collection",
                  "overview": "my overview"
                }
                """)

                // Test with bad token
                try await app.test(.POST, "api/package-collections",
                             headers: .bearerApplicationJSON("bad token"),
                             body: body,
                             afterResponse: { res async in
                    // validation
                    #expect(res.status == .unauthorized)
                })

                // Test with wrong tier
                try await app.test(.POST, "api/package-collections",
                             headers: .bearerApplicationJSON(.apiToken(secretKey: "secret", tier: .tier1)),
                             body: body,
                             afterResponse: { res async in
                    // validation
                    #expect(res.status == .unauthorized)
                })
            }
        }
    }

    @Test func packages_get() async throws {
        try await withDependencies {
            $0.environment.apiSigningKey = { "secret" }
            $0.environment.dbId = { nil }
            $0.httpClient.postPlausibleEvent = App.HTTPClient.noop
        } operation: {
            try await withApp { app in
                let owner = "owner"
                let repo = "repo"
                let p = try await savePackage(on: app.db, "1")
                let v = try Version(package: p, latest: .defaultBranch, reference: .branch("main"))
                try await v.save(on: app.db)
                try await Repository(package: p,
                                     defaultBranch: "main",
                                     license: .mit,
                                     name: repo,
                                     owner: owner).save(on: app.db)

                do {  // MUT - happy path
                    try await app.test(.GET, "api/packages/owner/repo",
                                       headers: .bearerApplicationJSON(try .apiToken(secretKey: "secret", tier: .tier3)),
                                       afterResponse: { res async throws in
                        // validation
                        #expect(res.status == .ok)
                        let model = try res.content.decode(API.PackageController.GetRoute.Model.self)
                        #expect(model.repositoryOwner == "owner")
                    })
                }

                do {  // MUT - unauthorized (no token provided)
                    try await app.test(.GET, "api/packages/owner/repo",
                                       headers: .applicationJSON,
                                       afterResponse: { res async in
                        // validation
                        #expect(res.status == .unauthorized)
                    })
                }

                do {  // MUT - unauthorized (wrong token provided)
                    try await app.test(.GET, "api/packages/owner/repo",
                                       headers: .bearerApplicationJSON("bad token"),
                                       afterResponse: { res async in
                        // validation
                        #expect(res.status == .unauthorized)
                    })
                }

                do {  // MUT - unauthorized (signed with wrong key)
                    try await app.test(.GET, "api/packages/unknown/package",
                                       headers: .bearerApplicationJSON((try .apiToken(secretKey: "wrong", tier: .tier3))),
                                       afterResponse: { res async in
                        // validation
                        #expect(res.status == .unauthorized)
                    })
                }
                do {  // MUT - package not found
                    try await app.test(.GET, "api/packages/unknown/package",
                                       headers: .bearerApplicationJSON((try .apiToken(secretKey: "secret", tier: .tier3))),
                                       afterResponse: { res async in
                        // validation
                        #expect(res.status == .notFound)
                    })
                }
            }
        }
    }

    @Test func dependencies_get() async throws {
        try await withDependencies {
            $0.environment.apiSigningKey = { "secret" }
            $0.httpClient.postPlausibleEvent = App.HTTPClient.noop
        } operation: {
            try await withApp { app in
                let pkg = try await savePackage(on: app.db, id: .id0, "http://github.com/foo/bar")
                try await Repository(package: pkg,
                                     defaultBranch: "default",
                                     name: "bar",
                                     owner: "foo").save(on: app.db)
                try await Version(package: pkg,
                                  commitDate: .t0,
                                  latest: .defaultBranch,
                                  reference: .branch("default"),
                                  resolvedDependencies: [])
                .save(on: app.db)

                // MUT
                try await app.test(.GET, "api/dependencies",
                                   headers: .bearerApplicationJSON((try .apiToken(secretKey: "secret", tier: .tier3))),
                                   afterResponse: { res async in
                    // validation
                    #expect(res.status == .ok)
                    #expect(res.body.asString().count > 0)
                })
            }
        }
    }

}


private extension HTTPHeaders {
    static var applicationJSON: Self {
        .init([("Content-Type", "application/json")])
    }

    static func bearerApplicationJSON(_ token: String) -> Self {
        .init([("Content-Type", "application/json"), ("Authorization", "Bearer \(token)")])
    }
}


extension AllTests.ApiTests {
    struct TestEvent: Equatable {
        var kind: Plausible.Event.Kind
        var path: Plausible.Path
    }
}


import Authentication
extension String {
    static func apiToken(secretKey: String, tier: Tier<V1>) throws -> String {
        let s = Signer(secretSigningKey: secretKey)
        return try s.generateToken(for: "", contact: "", tier: tier)
    }
}


private func logWarning(filePath: StaticString = #filePath,
                        lineNumber: UInt = #line,
                        testName: String = #function) {
    print("::error file=\(filePath),line=\(lineNumber),title=\(testName)::Direct comparison of updatedAt is working again, replace comparison with the Task.sleep delay.")
}
