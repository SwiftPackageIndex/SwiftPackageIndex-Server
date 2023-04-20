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

import PackageCollectionsSigning
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
            XCTAssertEqual(try res.content.decode(Search.Response.self),
                           .init(hasMoreResults: false,
                                 searchTerm: "",
                                 searchFilters: [],
                                 results: []))
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
                       defaultBranch: "main",
                       summary: "some package").save(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       lastCommitDate: .t0,
                       name: "name 2",
                       owner: "owner 2",
                       stars: 1234,
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
                      searchTerm: "foo bar",
                      searchFilters: [],
                      results: [
                        .package(
                            .init(packageId: UUID(uuidString: "4e256250-d1ea-4cdd-9fe9-0fc5dce17a80")!,
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
    }

    func test_post_buildReport() throws {
        // setup
        Current.builderToken = { "secr3t" }
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p, latest: .defaultBranch)
        try v.save(on: app.db).wait()
        let versionId = try v.requireID()

        do {  // MUT - initial insert
            let dto: API.PostBuildReportDTO = .init(
                buildCommand: "xcodebuild -scheme Foo",
                buildId: .id0,
                jobUrl: "https://example.com/jobs/1",
                logUrl: "log url",
                platform: .macosXcodebuild,
                resolvedDependencies: nil,
                runnerId: "some-runner",
                status: .failed,
                swiftVersion: .init(5, 2, 0)
            )
            let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
            try app.test(
                .POST,
                "api/versions/\(versionId)/build-report",
                headers: .bearerApplicationJSON("secr3t"),
                body: body,
                afterResponse: { res in
                    // validation
                    XCTAssertEqual(res.status, .noContent)
                    let builds = try Build.query(on: app.db).all().wait()
                    XCTAssertEqual(builds.count, 1)
                    let b = try builds.first.unwrap()
                    XCTAssertEqual(b.id, .id0)
                    XCTAssertEqual(b.buildCommand, "xcodebuild -scheme Foo")
                    XCTAssertEqual(b.jobUrl, "https://example.com/jobs/1")
                    XCTAssertEqual(b.logUrl, "log url")
                    XCTAssertEqual(b.platform, .macosXcodebuild)
                    XCTAssertEqual(b.runnerId, "some-runner")
                    XCTAssertEqual(b.status, .failed)
                    XCTAssertEqual(b.swiftVersion, .init(5, 2, 0))
                    XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)
                    let v = try Version.find(versionId, on: app.db).unwrap(or: Abort(.notFound)).wait()
                    XCTAssertEqual(v.resolvedDependencies, [])
                    // build failed, hence no package platform compatibility yet
                    let p = try XCTUnwrap(Package.find(p.id, on: app.db).wait())
                    XCTAssertEqual(p.platformCompatibility, [])
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
            try app.test(
                .POST,
                "api/versions/\(versionId)/build-report",
                headers: .bearerApplicationJSON("secr3t"),
                body: body,
                afterResponse: { res in
                    // validation
                    XCTAssertEqual(res.status, .noContent)
                    let builds = try Build.query(on: app.db).all().wait()
                    XCTAssertEqual(builds.count, 1)
                    let b = try builds.first.unwrap()
                    XCTAssertEqual(b.id, .id0)
                    XCTAssertEqual(b.platform, .macosXcodebuild)
                    XCTAssertEqual(b.status, .ok)
                    XCTAssertEqual(b.swiftVersion, .init(5, 2, 0))
                    XCTAssertEqual(try Build.query(on: app.db).count().wait(), 1)
                    let v = try Version.find(versionId, on: app.db).unwrap(or: Abort(.notFound)).wait()
                    XCTAssertEqual(v.resolvedDependencies,
                                   [.init(packageName: "foo",
                                          repositoryURL: "http://foo/bar")])
                    // build ok now -> package is macos compatible
                    let p = try XCTUnwrap(Package.find(p.id, on: app.db).wait())
                    XCTAssertEqual(p.platformCompatibility, [.macos])
                })
        }

        do {  // MUT - add another build to test Package.platformCompatibility
            let dto: API.PostBuildReportDTO = .init(
                buildId: .id1,
                platform: .ios,
                resolvedDependencies: [.init(packageName: "foo",
                                             repositoryURL: "http://foo/bar")],
                status: .ok,
                swiftVersion: .init(5, 2, 0)
            )
            let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
            try app.test(
                .POST,
                "api/versions/\(versionId)/build-report",
                headers: .bearerApplicationJSON("secr3t"),
                body: body,
                afterResponse: { res in
                    // validation
                    let builds = try Build.query(on: app.db).all().wait()
                    XCTAssertEqual(Set(builds.map(\.id)), Set([.id0, .id1]))
                    // additional ios build ok -> package is also ios compatible
                    let p = try XCTUnwrap(Package.find(p.id, on: app.db).wait())
                    XCTAssertEqual(p.platformCompatibility, [.ios, .macos])
                })
        }

    }

    func test_post_buildReport_infrastructureError() throws {
        // setup
        Current.builderToken = { "secr3t" }
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p)
        try v.save(on: app.db).wait()
        let versionId = try XCTUnwrap(v.id)

        let dto: API.PostBuildReportDTO = .init(
            buildCommand: "xcodebuild -scheme Foo",
            buildId: .id0,
            jobUrl: "https://example.com/jobs/1",
            logUrl: "log url",
            platform: .macosXcodebuild,
            status: .infrastructureError,
            swiftVersion: .init(5, 2, 0))
        let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))
        try app.test(
            .POST,
            "api/versions/\(versionId)/build-report",
            headers: .bearerApplicationJSON("secr3t"),
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .noContent)
                let builds = try Build.query(on: app.db).all().wait()
                XCTAssertEqual(builds.count, 1)
                let b = try builds.first.unwrap()
                XCTAssertEqual(b.status, .infrastructureError)
            })
    }

    func test_post_buildReport_unauthenticated() throws {
        // Ensure unauthenticated access raises a 401
        // setup
        Current.builderToken = { "secr3t" }
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p)
        try v.save(on: app.db).wait()
        let versionId = try XCTUnwrap(v.id)
        let dto: API.PostBuildReportDTO = .init(buildId: .id0,
                                                platform: .macosXcodebuild,
                                                status: .ok,
                                                swiftVersion: .init(5, 2, 0))
        let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))

        // MUT - no auth header
        try app.test(
            .POST,
            "api/versions/\(versionId)/build-report",
            headers: .applicationJSON,
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .unauthorized)
                XCTAssertEqual(try Build.query(on: app.db).count().wait(), 0)
            }
        )

        // MUT - wrong token
        try app.test(
            .POST,
            "api/versions/\(versionId)/build-report",
            headers: .bearerApplicationJSON("wrong"),
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .unauthorized)
                XCTAssertEqual(try Build.query(on: app.db).count().wait(), 0)
            }
        )

        // MUT - without server token
        Current.builderToken = { nil }
        try app.test(
            .POST,
            "api/versions/\(versionId)/build-report",
            headers: .bearerApplicationJSON("secr3t"),
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .unauthorized)
                XCTAssertEqual(try Build.query(on: app.db).count().wait(), 0)
            }
        )
    }

    func test_post_docReport() async throws {
        // setup
        Current.builderToken = { "secr3t" }
        let p = try await savePackageAsync(on: app.db, "1")
        let v = try Version(package: p, latest: .defaultBranch)
        try await v.save(on: app.db)
        let b = try Build(version: v, platform: .ios, status: .ok, swiftVersion: .v5_7)
        try await b.save(on: app.db)
        let buildId = try b.requireID()

        do {  // MUT - initial insert
            let dto: API.PostDocReportDTO = .init(error: "too large",
                                                  fileCount: 70_000,
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
                    XCTAssertEqual(res.status, .noContent)
                    let docUploads = try await DocUpload.query(on: app.db).all()
                    XCTAssertEqual(docUploads.count, 1)
                    let d = try docUploads.first.unwrap()
                    XCTAssertEqual(d.error, "too large")
                    XCTAssertEqual(d.fileCount, 70_000)
                    XCTAssertEqual(d.logUrl, "log url")
                    XCTAssertEqual(d.mbSize, 900)
                    XCTAssertEqual(d.status, .skipped)
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
                    XCTAssertEqual(res.status, .noContent)
                    let docUploads = try await DocUpload.query(on: app.db).all()
                    XCTAssertEqual(docUploads.count, 1)
                    let d = try docUploads.first.unwrap()
                    XCTAssertEqual(d.status, .ok)
                    try await d.$build.load(on: app.db)
                    try await d.build.$version.load(on: app.db)
                    XCTAssertEqual(d.build.version.docArchives,
                                   [.init(name: "foo", title: "Foo")])
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
                    XCTAssertEqual(res.status, .noContent)
                    let docUploads = try await DocUpload.query(on: app.db).all()
                    XCTAssertEqual(docUploads.count, 1)
                    let d = try docUploads.first.unwrap()
                    XCTAssertEqual(d.status, .pending)
                    try await d.$build.load(on: app.db)
                    try await d.build.$version.load(on: app.db)
                    XCTAssertEqual(d.build.version.docArchives,
                                   [.init(name: "foo", title: "Foo")])
                })
        }
    }

    func test_post_docReport_override() async throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2280
        // Ensure a subsequent doc report on a different build does not trip over a UK violation
        // setup
        Current.builderToken = { "secr3t" }
        let p = try await savePackageAsync(on: app.db, "1")
        let v = try Version(package: p, latest: .defaultBranch)
        try await v.save(on: app.db)
        let b1 = try Build(id: .id0, version: v, platform: .linux, status: .ok, swiftVersion: .v5_7)
        try await b1.save(on: app.db)
        let b2 = try Build(id: .id1, version: v, platform: .macosSpm, status: .ok, swiftVersion: .v5_7)
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
                    XCTAssertEqual(res.status, .noContent)
                    let docUploads = try await DocUpload.query(on: app.db).all()
                    XCTAssertEqual(docUploads.count, 1)
                    let d = try await DocUpload.query(on: app.db).first()
                    XCTAssertEqual(d?.$build.id, b1.id)
                    XCTAssertEqual(d?.status, .pending)
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
                    XCTAssertEqual(res.status, .noContent)
                    let docUploads = try await DocUpload.query(on: app.db).all()
                    XCTAssertEqual(docUploads.count, 1)
                    let d = try await DocUpload.query(on: app.db).first()
                    XCTAssertEqual(d?.$build.id, b2.id)
                    XCTAssertEqual(d?.status, .ok)
                })
        }
    }

    func test_post_docReport_non_existing_build() async throws {
        // setup
        Current.builderToken = { "secr3t" }
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
                    XCTAssertEqual(res.status, .notFound)
                    let docUploads = try await DocUpload.query(on: app.db).all()
                    XCTAssertEqual(docUploads.count, 0)
                })
        }
    }

    func test_post_docReport_unauthenticated() async throws {
        // setup
        Current.builderToken = { "secr3t" }
        let p = try await savePackageAsync(on: app.db, "1")
        let v = try Version(package: p, latest: .defaultBranch)
        try await v.save(on: app.db)
        let b = try Build(version: v, platform: .ios, status: .ok, swiftVersion: .v5_7)
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
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .unauthorized)
                try await XCTAssertEqualAsync(try await DocUpload.query(on: app.db).count(), 0)
            }
        )

        // MUT - wrong token
        try await app.test(
            .POST,
            "api/builds/\(buildId)/doc-report",
            headers: .bearerApplicationJSON("wrong"),
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .unauthorized)
                try await XCTAssertEqualAsync(try await DocUpload.query(on: app.db).count(), 0)
            }
        )

        // MUT - without server token
        Current.builderToken = { nil }
        try await app.test(
            .POST,
            "api/builds/\(buildId)/doc-report",
            headers: .bearerApplicationJSON("secr3t"),
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .unauthorized)
                try await XCTAssertEqualAsync(try await DocUpload.query(on: app.db).count(), 0)
            }
        )
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
        Current.triggerBuild = { _, _, _, _, _, _, _ in
            requestSent = true
            return self.app.eventLoopGroup.future(
                .init(status: .ok, webUrl: "http://web_url")
            )
        }

        // MUT
        try app.test(
            .POST,
            "api/versions/\(versionId)/trigger-build",
            headers: .bearerApplicationJSON("secr3t"),
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
            headers: .applicationJSON,
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .unauthorized)
            })

        // MUT - wrong token
        try app.test(
            .POST,
            "api/versions/\(versionId)/trigger-build",
            headers: .bearerApplicationJSON("wrong"),
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .unauthorized)
            })
    }

    func test_TriggerBuildRoute_query() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        let v = try Version(id: .id0, package: p, latest: .release, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        try Repository(package: p,
                       defaultBranch: "main",
                       license: .mit,
                       name: "repo",
                       owner: "owner").save(on: app.db).wait()
        // save decoy version
        try Version(id: .id1, package: p, latest: nil, reference: .tag(2, 0, 0))
            .save(on: app.db).wait()
        do { // save decoy package
            let p = try savePackage(on: app.db, "2")
            let v = try Version(package: p, latest: .release, reference: .tag(.init(2, 0, 0)))
            try v.save(on: app.db).wait()
            try Repository(package: p,
                           defaultBranch: "main",
                           license: .mit,
                           name: "decoy",
                           owner: "owner").save(on: app.db).wait()
        }

        // MUT
        let versionIds = try API.PackageController.TriggerBuildRoute
            .query(on: app.db, owner: "owner", repository: "repo").wait()

        // validate
        XCTAssertEqual(Set(versionIds), [.id0])
    }

    func test_post_build_trigger_package_name() async throws {
        // Test POST /packages/{owner}/{repo}/trigger-builds
        // setup
        Current.builderToken = { "secr3t" }
        Current.gitlabPipelineToken = { "ptoken" }
        let p = try savePackage(on: app.db, "1")
        try await Repository(package: p,
                       defaultBranch: "main",
                       license: .mit,
                       name: "bar",
                       owner: "foo").save(on: app.db)
        try await Version(package: p, reference: .branch("main")).save(on: app.db)
        try await Version(package: p, reference: .tag(.init(1, 2, 3))).save(on: app.db)
        let jpr = try await Package.fetchCandidate(app.db, id: p.id!).get()
        // update versions
        try await Analyze.updateLatestVersions(on: app.db, package: jpr)

        let owner = "foo"
        let repo = "bar"
        let dto: API.PostBuildTriggerDTO = .init(platform: .macosXcodebuild, swiftVersion: .init(5, 2, 4))
        let body: ByteBuffer = .init(data: try JSONEncoder().encode(dto))

        // we're testing the exact Gitlab trigger post request in detail in
        // GitlabBuilderTests - so here we just ensure two requests are being
        // made (one for each version to build)
        var requestsSent = 0
        Current.triggerBuild = { _, _, _, _, _, _, _ in
            requestsSent += 1
            return self.app.eventLoopGroup.future(
                .init(status: .ok, webUrl: "http://web_url")
            )
        }

        // MUT
        try app.test(
            .POST,
            "api/packages/\(owner)/\(repo)/trigger-builds",
            headers: .bearerApplicationJSON("secr3t"),
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
            headers: .applicationJSON,
            body: body,
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .unauthorized)
                XCTAssertEqual(requestsSent, 0)
            })
    }

    func test_BadgeRoute_query() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p, latest: .release, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        try Repository(package: p,
                       defaultBranch: "main",
                       license: .mit,
                       name: "repo",
                       owner: "owner").save(on: app.db).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .ok, swiftVersion: .v5_7)
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosSpm, status: .ok, swiftVersion: .v5_6)
            .save(on: app.db)
            .wait()
        do { // save decoy
            let p = try savePackage(on: app.db, "2")
            let v = try Version(package: p, latest: .release, reference: .tag(.init(2, 0, 0)))
            try v.save(on: app.db).wait()
            try Repository(package: p,
                           defaultBranch: "main",
                           license: .mit,
                           name: "decoy",
                           owner: "owner").save(on: app.db).wait()
            try Build(version: v, platform: .ios, status: .ok, swiftVersion: .v5_5)
                .save(on: app.db)
                .wait()
        }

        // MUT
        let sb = try API.PackageController.BadgeRoute.query(on: app.db, owner: "owner", repository: "repo").wait()

        // validate
        XCTAssertEqual(sb.builds.sorted(), [
            .init(.v5_6, .macosSpm, .ok),
            .init(.v5_7, .linux, .ok)
        ])
    }

    func test_get_badge() throws {
        // setup
        let owner = "owner"
        let repo = "repo"
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p, latest: .release, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        try Repository(package: p,
                       defaultBranch: "main",
                       license: .mit,
                       name: repo,
                       owner: owner).save(on: app.db).wait()
        // add builds
        try Build(version: v, platform: .linux, status: .ok, swiftVersion: .init(5, 6, 0))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .macosXcodebuild, status: .ok, swiftVersion: .init(5, 5, 2))
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

                let badge = try res.content.decode(Badge.self)
                XCTAssertEqual(badge.schemaVersion, 1)
                XCTAssertEqual(badge.label, "Swift Compatibility")
                XCTAssertEqual(badge.message, "5.6 | 5.5")
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

                let badge = try res.content.decode(Badge.self)
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
        try XCTSkipIf(!isRunningInCI && Current.collectionSigningPrivateKey() == nil, "Skip test for local user due to unset COLLECTION_SIGNING_PRIVATE_KEY env variable")
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
                         headers: .applicationJSON,
                         body: body,
                         afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .ok)
                let container = try res.content.decode(SignedCollection.self)
                XCTAssertFalse(container.signature.signature.isEmpty)
                // more details are tested in PackageCollectionTests
                XCTAssertEqual(container.collection.name, "my collection")
            })
        }
    }


    func test_package_collection_packageURLs() throws {
        try XCTSkipIf(!isRunningInCI && Current.collectionSigningPrivateKey() == nil, "Skip test for local user due to unset COLLECTION_SIGNING_PRIVATE_KEY env variable")
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
                         headers: .applicationJSON,
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
                     headers: .applicationJSON,
                     body: body,
                     afterResponse: { res in
                        // validation
                        XCTAssertEqual(res.status, .badRequest)
                     })
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
