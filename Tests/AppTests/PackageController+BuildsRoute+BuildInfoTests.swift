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

import Vapor
import XCTest


class PackageController_BuildsRoute_BuildInfoTests: AppTestCase {

    func test_buildStatus() throws {
        // Test build status aggregation, in particular see
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/666
        // setup
        // MUT & verification
        XCTAssertEqual([mkBuildInfo(.ok), mkBuildInfo(.failed)].compatibility, .compatible)
        XCTAssertEqual([mkBuildInfo(.triggered), mkBuildInfo(.triggered)].compatibility, .unknown)
        XCTAssertEqual([mkBuildInfo(.failed), mkBuildInfo(.triggered)].compatibility, .unknown)
        XCTAssertEqual([mkBuildInfo(.ok), mkBuildInfo(.triggered)].compatibility, .compatible)
    }

    func test_noneSucceeded() throws {
        XCTAssertTrue([mkBuildInfo(.failed), mkBuildInfo(.failed)].noneSucceeded)
        XCTAssertFalse([mkBuildInfo(.ok), mkBuildInfo(.failed)].noneSucceeded)
    }

    func test_anySucceeded() throws {
        XCTAssertTrue([mkBuildInfo(.ok), mkBuildInfo(.failed)].anySucceeded)
        XCTAssertFalse([mkBuildInfo(.failed), mkBuildInfo(.failed)].anySucceeded)
    }

    func test_nonePending() throws {
        XCTAssertTrue([mkBuildInfo(.ok), mkBuildInfo(.failed)].nonePending)
        XCTAssertFalse([mkBuildInfo(.ok), mkBuildInfo(.triggered)].nonePending)
        // timeouts will not be retried - therefore they are not pending
        XCTAssertTrue([mkBuildInfo(.ok), mkBuildInfo(.timeout)].nonePending)
        // infrastructure errors _will_ be retried - they are pending
        XCTAssertFalse([mkBuildInfo(.ok), mkBuildInfo(.infrastructureError)].nonePending)
    }

    func test_anyPending() throws {
        XCTAssertFalse([mkBuildInfo(.ok), mkBuildInfo(.failed)].anyPending)
        XCTAssertTrue([mkBuildInfo(.ok), mkBuildInfo(.triggered)].anyPending)
        // timeouts will not be retried - therefore they are not pending
        XCTAssertTrue([mkBuildInfo(.ok), mkBuildInfo(.timeout)].nonePending)
        // infrastructure errors _will_ be retried - they are pending
        XCTAssertFalse([mkBuildInfo(.ok), mkBuildInfo(.infrastructureError)].nonePending)
    }

    func test_Platform_isCompatible() throws {
        XCTAssertTrue(Build.Platform.iOS.isCompatible(with: .iOS))
        XCTAssertFalse(Build.Platform.iOS.isCompatible(with: .macOS))

        XCTAssertTrue(Build.Platform.macosSpm.isCompatible(with: .macOS))
        XCTAssertTrue(Build.Platform.macosXcodebuild.isCompatible(with: .macOS))
    }

}


private func mkBuildInfo(_ status: Build.Status) -> PackageController.BuildsRoute.BuildInfo {
    .init(versionKind: .defaultBranch, reference: .branch("main"), buildId: .id0, swiftVersion: .v1, platform: .iOS, status: status)
}
