@testable import App

import SnapshotTesting
import XCTVapor


class ApiTests: AppTestCase {
    
    func test_version() throws {
        try app.test(.GET, "api/version", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(API.Version.self), API.Version(version: "Unknown"))
        })
    }
    
    func test_search_noQuery() throws {
        try app.test(.GET, "api/search", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(Search.Result.self),
                           .init(hasMoreResults: false, results: []))
        })
    }
    
    func test_search_basic_param() throws {
        // setup
        let p1 = Package(id: UUID(uuidString: "442cf59f-0135-4d08-be00-bc9a7cebabd3")!,
                         url: "1")
        try p1.save(on: app.db).wait()
        let p2 = Package(id: UUID(uuidString: "4e256250-d1ea-4cdd-9fe9-0fc5dce17a80")!,
                         url: "2")
        try p2.save(on: app.db).wait()
        try Repository(package: p1,
                       summary: "some package",
                       defaultBranch: "main").save(on: app.db).wait()
        try Repository(package: p2,
                       summary: "foo bar package",
                       defaultBranch: "main",
                       name: "name 2",
                       owner: "owner 2").save(on: app.db).wait()
        try Version(package: p1, packageName: "Foo", reference: .branch("main")).save(on: app.db).wait()
        try Version(package: p2, packageName: "Bar", reference: .branch("main")).save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        try app.test(.GET, "api/search?query=foo%20bar", afterResponse: { res in
            // validation
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(
                try res.content.decode(Search.Result.self),
                .init(hasMoreResults: false,
                      results: [
                        .init(packageId: UUID(uuidString: "4e256250-d1ea-4cdd-9fe9-0fc5dce17a80")!,
                              packageName: "Bar",
                              packageURL: "/owner%202/name%202",
                              repositoryName: "name 2",
                              repositoryOwner: "owner 2",
                              summary: "foo bar package"),
                      ])
            )
        })
    }
    
    func test_post_build() throws {
        // setup
        Current.builderToken = { "secr3t" }
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p)
        try v.save(on: app.db).wait()
        let versionId = try XCTUnwrap(v.id)
        
        do {  // MUT - initial insert
            let dto: API.PostCreateBuildDTO = .init(buildCommand: "xcodebuild -scheme Foo",
                                                    jobUrl: "https://example.com/jobs/1",
                                                    logUrl: "log url",
                                                    platform: .macosXcodebuild,
                                                    status: .failed,
                                                    swiftVersion: .init(5, 2, 0))
            let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
            try app.test(
                .POST,
                "api/versions/\(versionId)/builds",
                headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer secr3t")]),
                body: body,
                afterResponse: { res in
                    // validation
                    XCTAssertEqual(res.status, .ok)
                    struct DTO: Decodable {
                        var id: Build.Id?
                    }
                    let dto = try JSONDecoder().decode(DTO.self, from: res.body)
                    let b = try XCTUnwrap(Build.find(dto.id, on: app.db).wait())
                    XCTAssertEqual(b.buildCommand, "xcodebuild -scheme Foo")
                    XCTAssertEqual(b.jobUrl, "https://example.com/jobs/1")
                    XCTAssertEqual(b.logUrl, "log url")
                    XCTAssertEqual(b.platform, .macosXcodebuild)
                    XCTAssertEqual(b.status, .failed)
                    XCTAssertEqual(b.swiftVersion, .init(5, 2, 0))
                    XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)
                })
        }
        
        do {  // MUT - update (upsert)
            let dto: API.PostCreateBuildDTO = .init(platform: .macosXcodebuild,
                                                    status: .ok,
                                                    swiftVersion: .init(5, 2, 0))
            let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
            try app.test(
                .POST,
                "api/versions/\(versionId)/builds",
                headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer secr3t")]),
                body: body,
                afterResponse: { res in
                    // validation
                    XCTAssertEqual(res.status, .ok)
                    struct DTO: Decodable {
                        var id: Build.Id?
                    }
                    let dto = try JSONDecoder().decode(DTO.self, from: res.body)
                    let b = try XCTUnwrap(Build.find(dto.id, on: app.db).wait())
                    XCTAssertEqual(b.platform, .macosXcodebuild)
                    XCTAssertEqual(b.status, .ok)
                    XCTAssertEqual(b.swiftVersion, .init(5, 2, 0))
                    XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)
                })
        }

    }
    func test_post_build_infrastructureError() throws {
        // setup
        Current.builderToken = { "secr3t" }
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p)
        try v.save(on: app.db).wait()
        let versionId = try XCTUnwrap(v.id)

        let dto: API.PostCreateBuildDTO = .init(
            buildCommand: "xcodebuild -scheme Foo",
            jobUrl: "https://example.com/jobs/1",
            logUrl: "log url",
            platform: .macosXcodebuild,
            status: .infrastructureError,
            swiftVersion: .init(5, 2, 0))
        let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
        try app.test(
            .POST,
            "api/versions/\(versionId)/builds",
            headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer secr3t")]),
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .ok)
                struct DTO: Decodable {
                    var id: Build.Id?
                }
                let dto = try JSONDecoder().decode(DTO.self, from: res.body)
                let b = try XCTUnwrap(Build.find(dto.id, on: app.db).wait())
                XCTAssertEqual(b.status, .infrastructureError)
            })
    }

    func test_post_build_unauthenticated() throws {
        // Ensure unauthenticated access raises a 401
        // setup
        Current.builderToken = { "secr3t" }
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p)
        try v.save(on: app.db).wait()
        let versionId = try XCTUnwrap(v.id)
        let dto: API.PostCreateBuildDTO = .init(platform: .macosXcodebuild,
                                                status: .ok,
                                                swiftVersion: .init(5, 2, 0))
        let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
        
        // MUT - no auth header
        try app.test(
            .POST,
            "api/versions/\(versionId)/builds",
            headers: .init([("Content-Type", "application/json")]),
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .unauthorized)
                XCTAssertEqual(try Build.query(on: app.db).count().wait(), 0)
            })
        
        // MUT - wrong token
        try app.test(
            .POST,
            "api/versions/\(versionId)/builds",
            headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer wrong")]),
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .unauthorized)
                XCTAssertEqual(try Build.query(on: app.db).count().wait(), 0)
            })
    }
    
    func test_post_build_unauthenticated_without_server_token() throws {
        // Ensure we don't allow API requests when no token is configured server-side
        // setup
        Current.builderToken = { nil }
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p)
        try v.save(on: app.db).wait()
        let versionId = try XCTUnwrap(v.id)
        let dto: API.PostCreateBuildDTO = .init(platform: .macosXcodebuild,
                                                status: .ok,
                                                swiftVersion: .init(5, 2, 0))
        let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
        
        // MUT - no auth header
        try app.test(
            .POST,
            "api/versions/\(versionId)/builds",
            headers: .init([("Content-Type", "application/json")]),
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .unauthorized)
                XCTAssertEqual(try Build.query(on: app.db).count().wait(), 0)
            })
        
        // MUT - with auth header
        try app.test(
            .POST,
            "api/versions/\(versionId)/builds",
            headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer token")]),
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .unauthorized)
                XCTAssertEqual(try Build.query(on: app.db).count().wait(), 0)
            })
    }
    
    func test_post_build_trigger() throws {
        // Test basic build trigger (high level API, details tested in GitlabBuilderTests)
        // setup
        Current.builderToken = { "secr3t" }
        Current.gitlabPipelineToken = { "ptoken" }
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p, reference: .tag(.init(1, 2, 3, "beta1")))
        try v.save(on: app.db).wait()
        let versionId = try XCTUnwrap(v.id)
        let dto: API.PostBuildTriggerDTO = .init(platform: .macosXcodebuild, swiftVersion: .init(5, 2, 4))
        let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
        
        // we're testing the exact Gitlab trigger post request in detail in
        // GitlabBuilderTests - so here we just ensure a request is being made
        var requestSent = false
        Current.triggerBuild = { _, _, _, _, _, _ in
            requestSent = true
            return self.app.eventLoopGroup.future(.ok)
        }
        
        // MUT
        try app.test(
            .POST,
            "api/versions/\(versionId)/trigger-build",
            headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer secr3t")]),
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertTrue(requestSent)
            })
    }
    
    func test_post_build_trigger_protected() throws {
        // Ensure unauthenticated access raises a 401
        // setup
        Current.builderToken = { "secr3t" }
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p)
        try v.save(on: app.db).wait()
        let versionId = try XCTUnwrap(v.id)
        let dto: API.PostBuildTriggerDTO = .init(platform: .macosXcodebuild, swiftVersion: .init(5, 2, 4))
        let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
        
        // MUT - no auth header
        try app.test(
            .POST,
            "api/versions/\(versionId)/trigger-build",
            headers: .init([("Content-Type", "application/json")]),
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .unauthorized)
            })
        
        // MUT - wrong token
        try app.test(
            .POST,
            "api/versions/\(versionId)/trigger-build",
            headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer wrong")]),
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .unauthorized)
            })
    }
    
    func test_post_build_trigger_package_name() throws {
        // Test POST /packages/{owner}/{repo}/trigger-builds
        // setup
        Current.builderToken = { "secr3t" }
        Current.gitlabPipelineToken = { "ptoken" }
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p,
                       defaultBranch: "main",
                       license: .mit,
                       name: "bar",
                       owner: "foo").save(on: app.db).wait()
        try Version(package: p, reference: .branch("main")).save(on: app.db).wait()
        try Version(package: p, reference: .tag(.init(1, 2, 3))).save(on: app.db).wait()
        // re-load repository relationship (required for updateLatestVersions)
        try p.$repositories.load(on: app.db).wait()
        // update versions
        _ = try updateLatestVersions(on: app.db, package: p).wait()

        let owner = "foo"
        let repo = "bar"
        let dto: API.PostBuildTriggerDTO = .init(platform: .macosXcodebuild, swiftVersion: .init(5, 2, 4))
        let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
        
        // we're testing the exact Gitlab trigger post request in detail in
        // GitlabBuilderTests - so here we just ensure two requests are being
        // made (one for each version to build)
        var requestsSent = 0
        Current.triggerBuild = { _, _, _, _, _, _ in
            requestsSent += 1
            return self.app.eventLoopGroup.future(.ok)
        }

        // MUT
        try app.test(
            .POST,
            "api/packages/\(owner)/\(repo)/trigger-builds",
            headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer secr3t")]),
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(requestsSent, 2)
            })
    }
    
    func test_post_build_trigger_package_name_protected() throws {
        // Test POST /packages/{owner}/{repo}/trigger-builds
        // Ensure unauthenticated access raises a 401
        // setup
        Current.builderToken = { "secr3t" }
        Current.gitlabPipelineToken = { "ptoken" }
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p)
        try v.save(on: app.db).wait()
        let owner = "owner"
        let repo = "repo"
        let dto: API.PostBuildTriggerDTO = .init(platform: .macosXcodebuild, swiftVersion: .init(5, 2, 4))
        let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
        
        var requestsSent = 0
        app.clients.use( { _ in MockClient { req, _ in
            requestsSent += 1
        }})
        
        // MUT - no auth header
        try app.test(
            .POST,
            "api/packages/\(owner)/\(repo)/trigger-builds",
            headers: .init([("Content-Type", "application/json")]),
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .unauthorized)
                XCTAssertEqual(requestsSent, 0)
            })
    }

    func test_get_badge() throws {
        // setup
        let owner = "owner"
        let repo = "repo"
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        try Repository(package: p,
                       defaultBranch: "main",
                       license: .mit,
                       name: repo,
                       owner: owner).save(on: app.db).wait()
        // re-load repository relationship (required for updateLatestVersions)
        try p.$repositories.load(on: app.db).wait()
        // update versions
        _ = try updateLatestVersions(on: app.db, package: p).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .ok, swiftVersion: .init(5, 3, 0))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosXcodebuild, status: .ok, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try p.$versions.load(on: app.db).wait()
        try p.versions.forEach {
            try $0.$builds.load(on: app.db).wait()
        }

        // MUT - swift versions
        try app.test(
            .GET,
            "api/packages/\(owner)/\(repo)/badge?type=swift-versions",
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .ok)

                XCTAssertEqual(try res.content.decode(Package.Badge.self),
                               Package.Badge(schemaVersion: 1,
                                             label: "Swift Compatibility",
                                             message: "5.3 | 5.2",
                                             color: "blue",
                                             cacheSeconds: 6*3600))
            })

        // MUT - platforms
        try app.test(
            .GET,
            "api/packages/\(owner)/\(repo)/badge?type=platforms",
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .ok)

                XCTAssertEqual(try res.content.decode(Package.Badge.self),
                               Package.Badge(schemaVersion: 1,
                                             label: "Platform Compatibility",
                                             message: "macOS | Linux",
                                             color: "blue",
                                             cacheSeconds: 6*3600))
            })

    }

    func test_package_collection_owner() throws {
        // setup
        let refDate = Date(timeIntervalSince1970: 0)
        Current.date = { refDate }
        let p1 = Package(id: UUID(uuidString: "442cf59f-0135-4d08-be00-bc9a7cebabd3")!,
                         url: "1")
        try p1.save(on: app.db).wait()
        let p2 = Package(id: UUID(uuidString: "4e256250-d1ea-4cdd-9fe9-0fc5dce17a80")!,
                         url: "2")
        try p2.save(on: app.db).wait()
        try Repository(package: p1,
                       summary: "some package",
                       defaultBranch: "main").save(on: app.db).wait()
        try Repository(package: p2,
                       summary: "foo bar package",
                       defaultBranch: "main",
                       name: "name 2",
                       owner: "foo").save(on: app.db).wait()
        try Version(package: p1, packageName: "Foo", reference: .branch("main")).save(on: app.db).wait()
        try Version(package: p2, packageName: "Bar", reference: .branch("main")).save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        do {  // MUT
            let body: ByteBuffer = .init(string: """
                {
                  "revision": 3,
                  "authorName": "author",
                  "owner": "owner",
                  "keywords": [
                    "a",
                    "b"
                  ],
                  "collectionName": "my collection",
                  "overview": "my overview"
                }
                """)

            try app.test(.POST,
                         "api/package-collections",
                         headers: .init([("Content-Type", "application/json")]),
                         body: body,
                         afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(
                    try res.content.decode(PackageCollection.self),
                    PackageCollection.init(name: "my collection",
                                           overview: "my overview",
                                           keywords: ["a", "b"],
                                           packages: [],
                                           formatVersion: .v1_0,
                                           revision: 3,
                                           generatedAt: refDate,
                                           generatedBy: .init(name: "author"))
                )
            })
        }
    }


    func test_package_collection_packageURLs() throws {
        // setup
        let refDate = Date(timeIntervalSince1970: 0)
        Current.date = { refDate }
        let p1 = Package(id: UUID(uuidString: "442cf59f-0135-4d08-be00-bc9a7cebabd3")!,
                         url: "1")
        try p1.save(on: app.db).wait()
        let p2 = Package(id: UUID(uuidString: "4e256250-d1ea-4cdd-9fe9-0fc5dce17a80")!,
                         url: "2")
        try p2.save(on: app.db).wait()
        try Repository(package: p1,
                       summary: "some package",
                       defaultBranch: "main").save(on: app.db).wait()
        try Repository(package: p2,
                       summary: "foo bar package",
                       defaultBranch: "main",
                       name: "name 2",
                       owner: "foo").save(on: app.db).wait()
        try Version(package: p1, packageName: "Foo", reference: .branch("main")).save(on: app.db).wait()
        try Version(package: p2, packageName: "Bar", reference: .branch("main")).save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        do {  // MUT
            let body: ByteBuffer = .init(string: """
                {
                  "revision": 3,
                  "authorName": "author",
                  "keywords": [
                    "a",
                    "b"
                  ],
                  "packageUrls": [
                    "1"
                  ],
                  "collectionName": "my collection",
                  "overview": "my overview"
                }
                """)

            try app.test(.POST,
                         "api/package-collections",
                         headers: .init([("Content-Type", "application/json")]),
                         body: body,
                         afterResponse: { res in
                            // validation
                            XCTAssertEqual(res.status, .ok)
                            let pkgColl = try res.content.decode(PackageCollection.self)
                            assertSnapshot(matching: pkgColl, as: .dump)
            })
        }
    }

    func test_package_collection_packageURLs_limit() throws {
        let dto = API.PostPackageCollectionPackageUrlsDTO(
            // request 21 urls - this should raise a 400
            packageUrls: (0...20).map(String.init)
        )
        let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))

        try app.test(.POST,
                     "api/package-collections",
                     headers: .init([("Content-Type", "application/json")]),
                     body: body,
                     afterResponse: { res in
                        // validation
                        XCTAssertEqual(res.status, .badRequest)
                     })
    }

}
