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
import XCTVapor


extension AllTests.KeywordControllerTests {

    @Test func query() async throws {
        try await withApp { app in
            // setup
            do {
                let p = try await savePackage(on: app.db, "0")
                try await Repository(package: p,
                                     keywords: ["bar"],
                                     name: "0",
                                     owner: "owner")
                .save(on: app.db)
                try await Version(package: p, latest: .defaultBranch).save(on: app.db)
            }
            do {
                let p = try await savePackage(on: app.db, "1")
                try await Repository(package: p,
                                     keywords: ["foo"],
                                     name: "1",
                                     owner: "owner")
                .save(on: app.db)
                try await Version(package: p, latest: .defaultBranch).save(on: app.db)
            }
            do {
                let p = try await savePackage(on: app.db, "2")
                try await Repository(package: p,
                                     name: "2",
                                     owner: "owner")
                .save(on: app.db)
                try await Version(package: p, latest: .defaultBranch).save(on: app.db)
            }
            // MUT
            let page = try await KeywordController.query(on: app.db,
                                                         keyword: "foo",
                                                         page: 1,
                                                         pageSize: 10)

            // validation
            #expect(page.results.map(\.repository.name) == ["1"])
            #expect(page.hasMoreResults == false)
        }
    }

    @Test func query_pagination() async throws {
        try await withApp { app in
            // setup
            for idx in (0..<9).shuffled() {
                let p = Package(url: "\(idx)".url, score: 10 - idx)
                try await p.save(on: app.db)
                try await Repository(package: p,
                                     keywords: ["foo"],
                                     name: "\(idx)",
                                     owner: "owner").save(on: app.db)
                try await Version(package: p, latest: .defaultBranch).save(on: app.db)
            }
            do {  // first page
                  // MUT
                let page = try await KeywordController.query(on: app.db,
                                                             keyword: "foo",
                                                             page: 1,
                                                             pageSize: 3)
                // validate
                #expect(page.results.map(\.repository.name) == ["0", "1", "2"])
                #expect(page.hasMoreResults == true)
            }
            do {  // second page
                  // MUT
                let page = try await KeywordController.query(on: app.db,
                                                             keyword: "foo",
                                                             page: 2,
                                                             pageSize: 3)
                // validate
                #expect(page.results.map(\.repository.name) == ["3", "4", "5"])
                #expect(page.hasMoreResults == true)
            }
            do {  // last page
                  // MUT
                let page = try await KeywordController.query(on: app.db,
                                                             keyword: "foo",
                                                             page: 3,
                                                             pageSize: 3)
                // validate
                #expect(page.results.map(\.repository.name) == ["6", "7", "8"])
                #expect(page.hasMoreResults == false)
            }
        }
    }

    @Test func show_keyword() async throws {
        try await withDependencies {
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                do {
                    let p = try await savePackage(on: app.db, "1")
                    try await Repository(package: p,
                                         keywords: ["foo"],
                                         name: "1",
                                         owner: "owner").save(on: app.db)
                    try await Version(package: p, latest: .defaultBranch).save(on: app.db)
                }
                // MUT
                try await app.test(.GET, "/keywords/foo") { req async in
                    // validate
                    #expect(req.status == .ok)
                }
            }
        }
    }

    @Test func not_found() async throws {
        try await withDependencies {
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                try await app.test(.GET, "/keywords/baz") { res async in
                    #expect(res.status == .notFound)
                }
            }
        }
    }

}
