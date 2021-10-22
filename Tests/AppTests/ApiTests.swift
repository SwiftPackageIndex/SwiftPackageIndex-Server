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

import SnapshotTesting
import XCTVapor


class ApiTests: AppTestCase {
    typealias PackageResult = PackageController.PackageResult
    
    func test_version() throws {
        try app.test(.GET, "api/version", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(API.Version.self), API.Version(version: "Unknown"))
        })
    }
    
    func test_search_noQuery() throws {
        try app.test(.GET, "api/search", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode(Search.Response.self),
                           .init(hasMoreResults: false, results: []))
        })
    }
    
    func test_search_basic() throws {
        // Basic search test, query and result formats
        // setup
        let p1 = Package(id: .id1, url: "1")
        try p1.save(on: app.db).wait()
        let p2 = Package(id: .id2, url: "2")
        try p2.save(on: app.db).wait()
        try Repository(package: p1,
                       defaultBranch: "main",
                       summary: "some package").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       name: "name 2",
                       owner: "owner 2",
                       summary: "foo bar package").save(on: app.db).wait()
        try Version(package: p1, packageName: "Foo", reference: .branch("main")).save(on: app.db).wait()
        try Version(package: p2, packageName: "Bar", reference: .branch("main")).save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()
        
        // MUT
        try app.test(.GET, "api/search?query=foo%20bar", afterResponse: { res in
            // validation
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(
                try res.content.decode(Search.Response.self),
                .init(hasMoreResults: false,
                      results: [
                        .package(
                            .init(packageId: .id2,
                                  packageName: "Bar",
                                  packageURL: "/owner%202/name%202",
                                  repositoryName: "name 2",
                                  repositoryOwner: "owner 2",
                                  summary: "foo bar package")
                        )
                      ])
            )
            assertSnapshot(matching: res.body.asString(), as: .lines)
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
            let dto: API.PostCreateBuildDTO = .init(
                buildCommand: "xcodebuild -scheme Foo",
                jobUrl: "https://example.com/jobs/1",
                logUrl: "log url",
                platform: .macosXcodebuild,
                resolvedDependencies: nil,
                status: .failed,
                swiftVersion: .init(5, 2, 0)
            )
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
                    let v = try Version.find(versionId, on: app.db).unwrap(or: Abort(.notFound)).wait()
                    XCTAssertEqual(v.resolvedDependencies, [])
                })
        }
        
        do {  // MUT - update (upsert)
            let dto: API.PostCreateBuildDTO = .init(
                platform: .macosXcodebuild,
                resolvedDependencies: [.init(packageName: "foo",
                                             repositoryURL: "http://foo/bar")],
                status: .ok,
                swiftVersion: .init(5, 2, 0)
            )
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
                    let v = try Version.find(versionId, on: app.db).unwrap(or: Abort(.notFound)).wait()
                    XCTAssertEqual(v.resolvedDependencies,
                                   [.init(packageName: "foo",
                                          repositoryURL: "http://foo/bar")])
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
            return self.app.eventLoopGroup.future(
                .init(status: .ok, webUrl: "http://web_url")
            )
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
        let jpr = try Package.fetchCandidate(app.db, id: p.id!).wait()
        // update versions
        _ = try updateLatestVersions(on: app.db, package: jpr).wait()

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
            return self.app.eventLoopGroup.future(
                .init(status: .ok, webUrl: "http://web_url")
            )
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
        let jpr = try Package.fetchCandidate(app.db, id: p.id!).wait()
        // update versions
        _ = try updateLatestVersions(on: app.db, package: jpr).wait()
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

                let badge = try res.content.decode(PackageResult.Badge.self)
                XCTAssertEqual(badge.schemaVersion, 1)
                XCTAssertEqual(badge.label, "Swift Compatibility")
                XCTAssertEqual(badge.message, "5.3 | 5.2")
                XCTAssertEqual(badge.isError, false)
                XCTAssertEqual(badge.color, "F05138")
                XCTAssertEqual(badge.cacheSeconds, 6*3600)
                XCTAssertNotNil(badge.logoSvg)
            })

        // MUT - platforms
        try app.test(
            .GET,
            "api/packages/\(owner)/\(repo)/badge?type=platforms",
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .ok)

                let badge = try res.content.decode(PackageResult.Badge.self)
                XCTAssertEqual(badge.schemaVersion, 1)
                XCTAssertEqual(badge.label, "Platform Compatibility")
                XCTAssertEqual(badge.message, "macOS | Linux")
                XCTAssertEqual(badge.isError, false)
                XCTAssertEqual(badge.color, "F05138")
                XCTAssertEqual(badge.cacheSeconds, 6*3600)
                XCTAssertNotNil(badge.logoSvg)
            })

    }

    func test_package_collection_owner() throws {
        // setup
        Current.date = { .t0 }
        let p1 = Package(id: .id1, url: "1")
        try p1.save(on: app.db).wait()
        try Repository(package: p1,
                       defaultBranch: "main",
                       name: "name 1",
                       owner: "foo",
                       summary: "foo bar package").save(on: app.db).wait()
        let v = try Version(package: p1,
                    latest: .release,
                    packageName: "Foo",
                    reference: .tag(1, 2, 3),
                            toolsVersion: "5.0")
        try v.save(on: app.db).wait()
        try Product(version: v, type: .library(.automatic), name: "lib")
            .save(on: app.db).wait()
        try Search.refresh(on: app.db).wait()

        do {  // MUT
            let body: ByteBuffer = .init(string: """
                {
                  "revision": 3,
                  "authorName": "author",
                  "owner": "foo",
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
                let collection = try res.content.decode(PackageCollection.self)
                // more details are tested in PackageCollectionTests
                XCTAssertEqual(collection.name, "my collection")
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
                       defaultBranch: "main",
                       summary: "some package").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       name: "name 2",
                       owner: "foo",
                       summary: "foo bar package").save(on: app.db).wait()
        do {
            let v = try Version(package: p1,
                                latest: .release,
                                packageName: "Foo",
                                reference: .tag(1, 2, 3),
                                toolsVersion: "5.3")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "p1")
                .save(on: app.db).wait()
        }
        do {
            let v = try Version(package: p2,
                                latest: .release,
                                packageName: "Bar",
                                reference: .tag(2, 0, 0),
                                toolsVersion: "5.4")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "p2")
                .save(on: app.db).wait()
        }
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
