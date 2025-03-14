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


extension AllTests.PackageInfoTests {

    @Test func title_package_name() async throws {
        // Ensure title is populated from package.name()
        try await withApp { app in
            // setup
            let p = try await savePackage(on: app.db, "1")
            try await Repository(package: p, name: "repo name", owner: "owner")
                .save(on: app.db)
            try await Version(package: p, latest: .defaultBranch, packageName: "package name")
                .save(on: app.db)
            let joined = try #require(try await Joined3<Package, Repository, Version>
                .query(on: app.db, version: .defaultBranch)
                .first())

            // MUT
            let pkgInfo = PackageInfo(package: joined)

            // validate
            #expect(pkgInfo?.title == "package name")
        }
    }

    @Test func title_repo_name() async throws {
        // Ensure title is populated from repoName if package.name() is nil
        try await withApp { app in
            // setup
            let p = try await savePackage(on: app.db, "1")
            try await Repository(package: p, name: "repo name", owner: "owner")
                .save(on: app.db)
            try await Version(package: p, latest: .defaultBranch, packageName: nil)
                .save(on: app.db)
            let joined = try #require(try await Joined3<Package, Repository, Version>
                .query(on: app.db, version: .defaultBranch)
                .first())

            // MUT
            let pkgInfo = PackageInfo(package: joined)

            // validate
            #expect(pkgInfo?.title == "repo name")
        }
    }
    
}
