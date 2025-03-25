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


extension AllTests.API_DependencyControllerTests {

    @Test func query() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, id: .id0, "http://github.com/foo/bar")
            try await Repository(package: pkg,
                                 defaultBranch: "default",
                                 name: "bar",
                                 owner: "foo").save(on: app.db)
            try await Version(package: pkg,
                              commitDate: .t0,
                              latest: .defaultBranch,
                              reference: .branch("default"),
                              resolvedDependencies: [
                                .init(packageName: "1", repositoryURL: "https://github.com/a/1"),
                                .init(packageName: "2", repositoryURL: "https://github.com/a/2"),
                              ])
            .save(on: app.db)

            // MUT
            let res = try await API.DependencyController.query(on: app.db)

            // validate
            #expect(res == [
                .init(id: .id0, url: .init(prefix: .http, hostname: "github.com", path: "foo/bar"), resolvedDependencies: [
                    .init(prefix: .https, hostname: "github.com", path: "a/1"),
                    .init(prefix: .https, hostname: "github.com", path: "a/2"),
                ])
            ])
        }
    }

}
