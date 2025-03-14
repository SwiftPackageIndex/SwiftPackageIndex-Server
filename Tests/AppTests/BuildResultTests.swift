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


extension AllTests.BuildResultTests {

    @Test func query() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1".url)
            let repo = try Repository(package: pkg)
            try await repo.save(on: app.db)
            let version = try Version(package: pkg)
            try await version.save(on: app.db)
            let build = try Build(version: version, platform: .iOS, status: .ok, swiftVersion: .init(5, 3, 0))
            try await build.save(on: app.db)
            
            // MUT
            let res = try await BuildResult.query(on: app.db, buildId: build.id!)
            
            // validate
            #expect(res.build.id == build.id)
            #expect(res.package.id == pkg.id)
            #expect(res.repository.id == repo.id)
            #expect(res.version.id == version.id)
        }
    }

}
