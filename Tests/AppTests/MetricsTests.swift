@testable import App

import XCTest


class MetricsTests: AppTestCase {

    func test_basic() throws {
        // setup - trigger build to increment counter
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        let versionId = UUID()
        do {  // save minimal package + version
            let p = Package(id: UUID(), url: "1")
            try p.save(on: app.db).wait()
            try Version(id: versionId, package: p, reference: .branch("main")).save(on: app.db).wait()
        }
        try triggerBuildsUnchecked(on: app.db,
                               client: app.client,
                               logger: app.logger,
                               triggers: [.init(versionId, [.init(.macosSpm, .v5_3)])]).wait()

        // MUT
        try app.test(.GET, "metrics", afterResponse: { res in
            // validation
            XCTAssertEqual(res.status, .ok)
            let content = res.body.asString()
            XCTAssertTrue(content.contains(
                #"spi_build_trigger_total{swiftVersion="5.3", platform="macos-spm"}"#
            ), "was:\n\(content)")
        })
    }

    func test_versions_added() throws {
        //setup
        let initialAdded = try XCTUnwrap(AppMetrics.analyzeVersionsAddedTotal?.get())
        let initialDeleted = try XCTUnwrap(AppMetrics.analyzeVersionsDeletedTotal?.get())
        let pkg = try savePackage(on: app.db, "1")
        let v = try Version(package: pkg)

        // MUT
        try applyVersionDelta(on: app.db, delta: (toAdd: [v], toDelete: [])).wait()

        // validation
        XCTAssertEqual(AppMetrics.analyzeVersionsAddedTotal?.get(), initialAdded + 1)
        XCTAssertEqual(AppMetrics.analyzeVersionsDeletedTotal?.get(), initialDeleted)
    }

}
