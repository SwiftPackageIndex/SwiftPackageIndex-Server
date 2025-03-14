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

import Testing
import Vapor


extension AllTests.PackageController_BuildsRoute_BuildInfoTests {

    @Test func buildStatus() throws {
        // Test build status aggregation, in particular see
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/666
        // setup
        // MUT & verification
        #expect([mkBuildInfo(.ok), mkBuildInfo(.failed)].compatibility == .compatible)
        #expect([mkBuildInfo(.triggered), mkBuildInfo(.triggered)].compatibility == .unknown)
        #expect([mkBuildInfo(.failed), mkBuildInfo(.triggered)].compatibility == .unknown)
        #expect([mkBuildInfo(.ok), mkBuildInfo(.triggered)].compatibility == .compatible)
    }

    @Test func noneSucceeded() throws {
        #expect([mkBuildInfo(.failed), mkBuildInfo(.failed)].noneSucceeded)
        #expect(![mkBuildInfo(.ok), mkBuildInfo(.failed)].noneSucceeded)
    }

    @Test func anySucceeded() throws {
        #expect([mkBuildInfo(.ok), mkBuildInfo(.failed)].anySucceeded)
        #expect(![mkBuildInfo(.failed), mkBuildInfo(.failed)].anySucceeded)
    }

    @Test func nonePending() throws {
        #expect([mkBuildInfo(.ok), mkBuildInfo(.failed)].nonePending)
        #expect(![mkBuildInfo(.ok), mkBuildInfo(.triggered)].nonePending)
        // timeouts will not be retried - therefore they are not pending
        #expect([mkBuildInfo(.ok), mkBuildInfo(.timeout)].nonePending)
        // infrastructure errors _will_ be retried - they are pending
        #expect(![mkBuildInfo(.ok), mkBuildInfo(.infrastructureError)].nonePending)
    }

    @Test func anyPending() throws {
        #expect(![mkBuildInfo(.ok), mkBuildInfo(.failed)].anyPending)
        #expect([mkBuildInfo(.ok), mkBuildInfo(.triggered)].anyPending)
        // timeouts will not be retried - therefore they are not pending
        #expect([mkBuildInfo(.ok), mkBuildInfo(.timeout)].nonePending)
        // infrastructure errors _will_ be retried - they are pending
        #expect(![mkBuildInfo(.ok), mkBuildInfo(.infrastructureError)].nonePending)
    }

    @Test func Platform_isCompatible() throws {
        #expect(Build.Platform.iOS.isCompatible(with: .iOS))
        #expect(!Build.Platform.iOS.isCompatible(with: .macOS))

        #expect(Build.Platform.macosSpm.isCompatible(with: .macOS))
        #expect(Build.Platform.macosXcodebuild.isCompatible(with: .macOS))
    }

}


private func mkBuildInfo(_ status: Build.Status) -> PackageController.BuildsRoute.BuildInfo {
    .init(versionKind: .defaultBranch, reference: .branch("main"), buildId: .id0, swiftVersion: .v1, platform: .iOS, status: status)
}
