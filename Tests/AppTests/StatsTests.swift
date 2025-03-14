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

import Foundation

@testable import App

import Testing


extension AllTests.StatsTests {

    @Test func fetch() async throws {
        try await withApp { app in
            // setup
            do {
                let pkg = Package(id: UUID(), url: "1")
                try await pkg.save(on: app.db)
            }
            do {
                let pkg = Package(id: UUID(), url: "2")
                try await pkg.save(on: app.db)
            }
            try await Stats.refresh(on: app.db)
            
            // MUT
            let res = try await Stats.fetch(on: app.db)
            
            // validate
            #expect(res == .some(.init(packageCount: 2)))
        }
    }

}
