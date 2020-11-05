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
        _ = try Build.trigger(database: app.db,
                              client: app.client,
                              platform: .macosSpm,
                              swiftVersion: .v5_3,
                              versionId: versionId).wait()

        // MUT
        try app.test(.GET, "metrics", afterResponse: { res in
            // validation
            XCTAssertEqual(res.status, .ok)
            XCTAssertTrue(res.body.asString().contains(
                """
                # TYPE spi_build_trigger_total counter
                spi_build_trigger_total 0
                spi_build_trigger_total{swiftVersion="5.3", platform="macos-spm"} 1
                """
            ))
        })
    }

}
