@testable import App

import XCTVapor


class ApiTests: AppTestCase {
    
    func test_version() throws {
        try app.test(.GET, "api/version") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(API.Version.self),
                           API.Version(version: "dev - will be overriden in release builds"))
        }
    }
    
    func test_search_noQuery() throws {
        try app.test(.GET, "api/search") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(Search.Result.self),
                           .init(hasMoreResults: false, results: []))
        }
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
        try app.test(.GET, "api/search?query=foo%20bar") { res in
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
        }
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
                                                    platform: .macosXcodebuild,
                                                    status: .failed,
                                                    swiftVersion: .init(5, 2, 0))
            let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
            try app.test(
                .POST,
                "api/versions/\(versionId)/builds",
                headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer secr3t")]),
                body: body
            ) { res in
                // validation
                XCTAssertEqual(res.status, .ok)
                struct DTO: Decodable {
                    var id: Build.Id?
                }
                let dto = try JSONDecoder().decode(DTO.self, from: res.body)
                let b = try XCTUnwrap(Build.find(dto.id, on: app.db).wait())
                XCTAssertEqual(b.buildCommand, "xcodebuild -scheme Foo")
                XCTAssertEqual(b.platform, .macosXcodebuild)
                XCTAssertEqual(b.status, .failed)
                XCTAssertEqual(b.swiftVersion, .init(5, 2, 0))
                XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)
            }
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
                body: body
            ) { res in
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
            }
        }

    }

    func test_post_build_contentSize() throws {
        // Ensure large payloads are rejected
        // setup
        Current.builderToken = { "secr3t" }
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p)
        try v.save(on: app.db).wait()
        let versionId = try XCTUnwrap(v.id)

        do {  // 90k is ok
            let payload = String.init(repeating: "*", count: 90_000)
            let dto: API.PostCreateBuildDTO = .init(logs: payload,
                                                    platform: .macosXcodebuild,
                                                    status: .ok,
                                                    swiftVersion: .init(5, 2, 0))
            let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
            // testable(method: .running) is required to force the same code path
            // as production code
            // https://discordapp.com/channels/431917998102675485/444937269808332801/732945565268312106
            let _app = try app.testable(method: .running)
            try _app.test(
                .POST,
                "api/versions/\(versionId)/builds",
                headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer secr3t")]),
                body: body
            ) { res in
                // validation
                XCTAssertEqual(res.status, .ok)
            }
        }

        do {  // 100k isn't
            let payload = String.init(repeating: "*", count: 100_000)
            let dto: API.PostCreateBuildDTO = .init(logs: payload,
                                                    platform: .macosXcodebuild,
                                                    status: .ok,
                                                    swiftVersion: .init(5, 2, 0))
            let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
            let _app = try app.testable(method: .running)
            try _app.test(
                .POST,
                "api/versions/\(versionId)/builds",
                headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer secr3t")]),
                body: body
            ) { res in
                // validation
                XCTAssertEqual(res.status, .payloadTooLarge)
            }
        }
    }

    func test_post_build_logs_basic() throws {
        // Tests storing logs and log_url
        // setup
        Current.builderToken = { "secr3t" }
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p)
        try v.save(on: app.db).wait()
        let versionId = try XCTUnwrap(v.id)

        let dto: API.PostCreateBuildDTO = .init(logs: "logs",
                                                logUrl: "log url",
                                                platform: .macosXcodebuild,
                                                status: .failed,
                                                swiftVersion: .init(5, 2, 0))
        let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
        try app.test(
            .POST,
            "api/versions/\(versionId)/builds",
            headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer secr3t")]),
            body: body
        ) { res in
            // validation
            XCTAssertEqual(res.status, .ok)
            struct DTO: Decodable {
                var id: Build.Id?
            }
            let dto = try JSONDecoder().decode(DTO.self, from: res.body)
            let b = try XCTUnwrap(Build.find(dto.id, on: app.db).wait())
            XCTAssertEqual(b.logs, "logs")
            XCTAssertEqual(b.logUrl, "log url")
        }
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
            body: body) { res in
            // validation
            XCTAssertEqual(res.status, .unauthorized)
            XCTAssertEqual(try Build.query(on: app.db).count().wait(), 0)
        }
        
        // MUT - wrong token
        try app.test(
            .POST,
            "api/versions/\(versionId)/builds",
            headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer wrong")]),
            body: body) { res in
            // validation
            XCTAssertEqual(res.status, .unauthorized)
            XCTAssertEqual(try Build.query(on: app.db).count().wait(), 0)
        }
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
            body: body) { res in
            // validation
            XCTAssertEqual(res.status, .unauthorized)
            XCTAssertEqual(try Build.query(on: app.db).count().wait(), 0)
        }
        
        // MUT - with auth header
        try app.test(
            .POST,
            "api/versions/\(versionId)/builds",
            headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer token")]),
            body: body) { res in
            // validation
            XCTAssertEqual(res.status, .unauthorized)
            XCTAssertEqual(try Build.query(on: app.db).count().wait(), 0)
        }
    }
    
    func test_post_build_trigger() throws {
        // Ensure unauthenticated access raises a 401
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
        app.clients.use( { _ in MockClient { req, _ in
            requestSent = true
        }})
        
        // MUT
        try app.test(
            .POST,
            "api/versions/\(versionId)/trigger-build",
            headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer secr3t")]),
            body: body) { res in
            // validation
            XCTAssertEqual(res.status, .ok)
            XCTAssertTrue(requestSent)
        }
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
            body: body) { res in
            // validation
            XCTAssertEqual(res.status, .unauthorized)
        }
        
        // MUT - wrong token
        try app.test(
            .POST,
            "api/versions/\(versionId)/trigger-build",
            headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer wrong")]),
            body: body) { res in
            // validation
            XCTAssertEqual(res.status, .unauthorized)
        }
    }
    
    func test_post_build_trigger_package_name() throws {
        // Test POST /packages/{owner}/{repo}/trigger-builds
        // Ensure unauthenticated access raises a 401
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
        app.clients.use( { _ in MockClient { req, _ in
            requestsSent += 1
        }})
        
        // MUT
        try app.test(
            .POST,
            "api/packages/\(owner)/\(repo)/trigger-builds",
            headers: .init([("Content-Type", "application/json"), ("Authorization", "Bearer secr3t")]),
            body: body) { res in
            // validation
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(requestsSent, 2)
        }
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
            body: body) { res in
            // validation
            XCTAssertEqual(res.status, .unauthorized)
            XCTAssertEqual(requestsSent, 0)
        }
    }

    func test_get_shield() throws {
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

        // MUT - no auth header
        try app.test(
            .GET,
            "api/packages/\(owner)/\(repo)/badge?type=swift-versions") { res in
            // validation
            XCTAssertEqual(res.status, .ok)

            XCTAssertEqual(try res.content.decode(Package.Badge.self),
                           Package.Badge(schemaVersion: 1,
                                         label: "Swift Compatibility",
                                         message: "5.3 | 5.2",
                                         color: "blue",
                                         cacheSeconds: 6*3600))
        }

    }

}
