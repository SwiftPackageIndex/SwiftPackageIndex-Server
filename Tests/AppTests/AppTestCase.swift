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

import SQLKit
import XCTVapor
@testable import App

class AppTestCase: XCTestCase {
    var app: Application!
    let logger = CapturingLogger()

    func future<T>(_ value: T) -> EventLoopFuture<T> {
        app.eventLoopGroup.next().future(value)
    }

    override func setUp() async throws {
        try await super.setUp()
        app = try await setup(.testing)

        Current.setLogger(.init(label: "test", factory: { _ in logger }))

        // Silence app logging
        app.logger = .init(label: "noop") { _ in SwiftLogNoOpLogHandler() }
    }

    override func tearDown() async throws {
        app.shutdown()
        try await super.tearDown()
    }
}


extension AppTestCase {
    func renderSQL(_ builder: SQLSelectBuilder) -> String {
        renderSQL(builder.query)
    }

    func renderSQL(_ query: SQLExpression) -> String {
        var serializer = SQLSerializer(database: app.db as! SQLDatabase)
        query.serialize(to: &serializer)
        return serializer.sql
    }

    func binds(_ builder: SQLSelectBuilder?) -> [String] {
        binds(builder?.query)
    }

    func binds(_ query: SQLExpression?) -> [String] {
        var serializer = SQLSerializer(database: app.db as! SQLDatabase)
        query?.serialize(to: &serializer)
        return serializer.binds.reduce(into: []) { result, bind in
            switch bind {
                case let bind as Date:
                    result.append(DateFormatter.filterParseFormatter.string(from: bind))
                case let bind as Set<Package.PlatformCompatibility>:
                    let s = bind.map(\.rawValue).sorted().joined(separator: ",")
                    result.append("{\(s)}")
                case let bind as Set<ProductTypeSearchFilter.ProductType>:
                    let s = bind.map(\.rawValue).sorted().joined(separator: ",")
                    result.append("{\(s)}")
                default:
                    result.append("\(bind)")
            }
        }
    }
}
