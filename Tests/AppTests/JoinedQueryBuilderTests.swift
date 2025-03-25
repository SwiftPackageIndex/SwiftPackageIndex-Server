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

import FluentKit
import Testing


/// `JoinedQueryBuilder` is essentially a "pass-through" class that wraps a `QueryBuilder`
/// and forwards method calls to it. This test class tests this behaviour in principle for `sort`
/// but not for any other methods at this time, because the instrumentation is quite mechanical
/// and essentially compiler checked.
extension AllTests.JoinedQueryBuilderTests {

    @Test func sort() async throws {
        try await withApp { app in
            // setup
            for idx in (0..<3).shuffled() {
                try await Package(url: "\(idx)".url).save(on: app.db)
            }
            // query helper
            func query() -> JoinedQueryBuilder<Package> {
                JoinedQueryBuilder<Package>(
                    queryBuilder: Package.query(on: app.db)
                )
            }
            
            do {  // test sort(_ sort: DatabaseQuery.Sort)
                  // MUT
                let res = try await query()
                    .sort(DatabaseQuery.Sort.sort(.sql(unsafeRaw: "url"), .descending))
                    .all()
                
                // validate
                #expect(res.map(\.url) == ["2", "1", "0"])
            }
            
            do {  // test sort<Field>(_ field: KeyPath<...>, _ direction:)
                  // MUT
                let res = try await query()
                    .sort(\.$url, .descending)
                    .all()
                
                // validate
                #expect(res.map(\.url) == ["2", "1", "0"])
            }
            
            do {  // test sort(_ field: DatabaseQuery.Field, _ direction:)
                  // MUT
                let res = try await query()
                    .sort(DatabaseQuery.Field.sql(unsafeRaw: "url"), .descending)
                    .all()
                
                // validate
                #expect(res.map(\.url) == ["2", "1", "0"])
            }
        }
    }

}

extension App.Package: App.ModelInitializable {
    convenience public init(model: Package) {
        self.init(id: model.id,
                  url: model.url.url,
                  score: model.score,
                  status: model.status,
                  processingStage: model.processingStage)
    }
}
