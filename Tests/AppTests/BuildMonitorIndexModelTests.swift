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

import Plot
import XCTVapor

class BuildMonitorIndexModelTests: AppTestCase {

    func test_init_from_Build() async throws {
        do {
            let package = try await savePackage(on: app.db, "https://github.com/daveverwer/LeftPad")
            let version = try Version(package: package,
                                      latest: .defaultBranch,
                                      packageName: "LeftPad from Version.packageName",
                                      reference: .branch("main"))
            try await version.save(on: app.db)
            try await Build(id: .id0,
                            version: version,
                            platform: .macosXcodebuild,
                            status: .ok,
                            swiftVersion: .init(5, 6, 0)).save(on: app.db)
            try await Repository(package: package,
                                 ownerName: "Dave Verwer from Repository.ownerName").save(on: app.db)
        }

        // Query results back through the Joined4
        let buildResult = try await BuildResult.query(on: app.db).first().unwrap()

        // MUT
        let model = try XCTUnwrap(BuildMonitorIndex.Model(buildResult: buildResult))

        XCTAssertEqual(model.buildId, .id0)
        XCTAssertEqual(model.packageName, "LeftPad from Version.packageName")
        XCTAssertEqual(model.repositoryOwnerName, "Dave Verwer from Repository.ownerName")
        XCTAssertEqual(model.platform, .macosXcodebuild)
        XCTAssertEqual(model.swiftVersion, .init(5, 6, 0))
        XCTAssertEqual(model.reference, .branch("main"))
        XCTAssertEqual(model.referenceKind, .defaultBranch)
        XCTAssertEqual(model.status, .ok)
    }

    func test_init_from_Build_without_repository_name() async throws {
        do {
            let package = try await savePackage(on: app.db, "https://github.com/daveverwer/LeftPad")
            let version = try Version(package: package,
                                      packageName: nil) // Deliberately missing a `packageName`
            try await version.save(on: app.db)
            try await Build(version: version,
                            platform: .macosXcodebuild,
                            status: .ok,
                            swiftVersion: .init(5, 6, 0)).save(on: app.db)
            try await Repository(package: package,
                                 name: "LeftPad from Repository.name").save(on: app.db)
        }

        // Query results back through the Joined4
        let buildResult = try await BuildResult.query(on: app.db).first().unwrap()

        // MUT
        let model = try XCTUnwrap(BuildMonitorIndex.Model(buildResult: buildResult))

        XCTAssertEqual(model.packageName, "LeftPad from Repository.name")
    }

    func test_init_from_Build_with_no_package_name() async throws {
        do {
            let package = try await savePackage(on: app.db, "https://github.com/daveverwer/LeftPad")
            let version = try Version(package: package,
                                      packageName: nil) // Deliberately missing a `packageName`
            try await version.save(on: app.db)
            try await Build(version: version,
                            platform: .macosXcodebuild,
                            status: .ok,
                            swiftVersion: .init(5, 6, 0)).save(on: app.db)
            try await Repository(package: package,
                                 name: nil) // Deliberately missing a `name`
            .save(on: app.db)
        }

        // Query results back through the Joined4
        let buildResult = try await BuildResult.query(on: app.db).first().unwrap()

        // MUT
        let model = try XCTUnwrap(BuildMonitorIndex.Model(buildResult: buildResult))

        XCTAssertEqual(model.packageName, "Unknown Package")
    }

    func test_init_from_Build_without_ownerName() async throws {
        do {
            let package = try await savePackage(on: app.db, "https://github.com/daveverwer/LeftPad")
            let version = try Version(package: package)
            try await version.save(on: app.db)
            try await Build(version: version,
                            platform: .macosXcodebuild,
                            status: .ok,
                            swiftVersion: .init(5, 6, 0)).save(on: app.db)
            try await Repository(package: package,
                                 owner: "daveverwer from Repository.owner",
                                 ownerName: nil) // Deliberately missing an `ownerName`
            .save(on: app.db)
        }

        // Query results back through the Joined4
        let buildResult = try await BuildResult.query(on: app.db).first().unwrap()

        // MUT
        let model = try XCTUnwrap(BuildMonitorIndex.Model(buildResult: buildResult))

        XCTAssertEqual(model.repositoryOwnerName, "daveverwer from Repository.owner")
    }
}
