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
import Prometheus
import XCTest


class MetricsTests: AppTestCase {

    func test_basic() async throws {
        try await withDependencies {
            $0.buildSystem.triggerBuild = { @Sendable _, _, _, _, _, _, _ in
                    .init(status: .ok, webUrl: "")
            }
            $0.environment.builderToken = { "builder token" }
            $0.environment.gitlabPipelineToken = { "pipeline token" }
        } operation: {
            // setup - trigger build to increment counter
            let versionId = UUID()
            do {  // save minimal package + version
                let p = Package(id: UUID(), url: "1")
                try await p.save(on: app.db)
                try await Version(id: versionId, package: p, reference: .branch("main")).save(on: app.db)
            }
            try await triggerBuildsUnchecked(on: app.db,
                                             triggers: [
                                                .init(versionId: versionId,
                                                      buildPairs: [.init(.macosSpm, .v3)])!
                                             ])
            
            // MUT
            try await app.test(.GET, "metrics", afterResponse: { res async in
                // validation
                XCTAssertEqual(res.status, .ok)
                let content = res.body.asString()
                XCTAssertTrue(content.contains(
                    #"spi_build_trigger_count{swiftVersion="\#(SwiftVersion.v3)", platform="macos-spm"}"#
                ), "was:\n\(content)")
            })
        }
    }

    func test_versions_added() async throws {
        // setup
        let initialAddedBranch = try XCTUnwrap(
            AppMetrics.analyzeVersionsAddedCount?.get(.versionLabels(kind: .branch))
        )
        let initialAddedTag = try XCTUnwrap(
            AppMetrics.analyzeVersionsAddedCount?.get(.versionLabels(kind: .tag))
        )
        let initialDeletedBranch = try XCTUnwrap(
            AppMetrics.analyzeVersionsDeletedCount?.get(.versionLabels(kind: .branch))
        )
        let initialDeletedTag = try XCTUnwrap(
            AppMetrics.analyzeVersionsDeletedCount?.get(.versionLabels(kind: .tag))
        )
        let pkg = try await savePackage(on: app.db, "1")
        let new = [
            try Version(package: pkg, reference: .branch("main")),
            try Version(package: pkg, reference: .tag(1, 2, 3)),
            try Version(package: pkg, reference: .tag(2, 0, 0)),
        ]
        let del = [
            try Version(package: pkg, reference: .branch("main")),
            try Version(package: pkg, reference: .tag(1, 0, 0)),
        ]
        try await del.save(on: app.db)

        // MUT
        try await Analyze.applyVersionDelta(on: app.db,
                                            delta: .init(toAdd: new, toDelete: del))

        // validation
        XCTAssertEqual(
            AppMetrics.analyzeVersionsAddedCount?.get(.versionLabels(kind: .branch)),
            initialAddedBranch + 1
        )
        XCTAssertEqual(
            AppMetrics.analyzeVersionsAddedCount?.get(.versionLabels(kind: .tag)),
            initialAddedTag + 2
        )
        XCTAssertEqual(
            AppMetrics.analyzeVersionsDeletedCount?.get(.versionLabels(kind: .branch)),
            initialDeletedBranch + 1
        )
        XCTAssertEqual(
            AppMetrics.analyzeVersionsDeletedCount?.get(.versionLabels(kind: .tag)),
            initialDeletedTag + 1
        )
    }

    func test_reconcileDurationSeconds() async throws {
        try await withDependencies {
            $0.packageListRepository.fetchPackageList = { @Sendable _ in ["1", "2", "3"].asURLs }
            $0.packageListRepository.fetchPackageDenyList = { @Sendable _ in [] }
            $0.packageListRepository.fetchCustomCollections = { @Sendable _ in [] }
        } operation: {
            // MUT
            try await reconcile(client: app.client, database: app.db)

            // validation
            XCTAssert((AppMetrics.reconcileDurationSeconds?.get()) ?? 0 > 0)
        }
    }

    func test_ingestDurationSeconds() async throws {
        // setup
        let pkg = try await savePackage(on: app.db, "1")

        // MUT
        try await Ingestion.ingest(client: app.client, database: app.db, mode: .id(pkg.id!))

        // validation
        XCTAssert((AppMetrics.ingestDurationSeconds?.get()) ?? 0 > 0)
    }

    func test_analyzeDurationSeconds() async throws {
        try await withDependencies {
            $0.fileManager.fileExists = { @Sendable _ in true }
        } operation: {
            // setup
            let pkg = try await savePackage(on: app.db, "1")

            // MUT
            try await Analyze.analyze(client: app.client, database: app.db, mode: .id(pkg.id!))

            // validation
            XCTAssert((AppMetrics.analyzeDurationSeconds?.get()) ?? 0 > 0)
        }
    }

    func test_triggerBuildsDurationSeconds() async throws {
        try await withDependencies {
            $0.environment.allowBuildTriggers = { true }
        } operation: {
            // setup
            let pkg = try await savePackage(on: app.db, "1")
            
            // MUT
            try await triggerBuilds(on: app.db, mode: .packageId(pkg.id!, force: true))
            
            // validation
            XCTAssert((AppMetrics.buildTriggerDurationSeconds?.get()) ?? 0 > 0)
            print(AppMetrics.buildTriggerDurationSeconds!.get())
        }
    }

}


extension DimensionLabels {
    enum VersionKind: String {
        case branch
        case tag
    }

    static func versionLabels(kind: VersionKind) -> Self {
        .init([
            ("kind", kind.rawValue),
        ])
    }
}
