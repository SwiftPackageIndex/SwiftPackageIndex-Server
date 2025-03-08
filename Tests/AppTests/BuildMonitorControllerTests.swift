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
import Testing
import Vapor


extension AllTests.BuildMonitorControllerTests {

    @Test func show_owner() async throws {
        try await withDependencies {
            $0.date.now = .now
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                let package = try await savePackage(on: app.db, "https://github.com/daveverwer/LeftPad")
                let version = try Version(package: package)
                try await version.save(on: app.db)
                try await Build(version: version,
                                platform: .macosXcodebuild,
                                status: .ok,
                                swiftVersion: .init(5, 6, 0)).save(on: app.db)
                try await Repository(package: package).save(on: app.db)

                // MUT
                try await app.test(.GET, "/build-monitor", afterResponse: { response async in
                    #expect(response.status == .ok)
                })
            }
        }
    }
}
