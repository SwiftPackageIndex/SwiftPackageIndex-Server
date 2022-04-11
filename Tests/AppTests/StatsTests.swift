// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import XCTVapor


class StatsTests: AppTestCase {
    
    func test_fetch() throws {
        // setup
        do {
            let pkg = Package(id: UUID(), url: "1")
            try pkg.save(on: app.db).wait()
        }
        do {
            let pkg = Package(id: UUID(), url: "2")
            try pkg.save(on: app.db).wait()
        }
        try Stats.refresh(on: app.db).wait()
        
        // MUT
        let res = try Stats.fetch(on: app.db).wait()
        
        // validate
        XCTAssertEqual(res, .some(.init(packageCount: 2)))
    }
    
}
