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

import Fluent
import SQLKit


// FIXME: Check if we can just create a PostgresDB object from scratch rather than using withApp and app.db for this at the call site (i.e. check if these need to be extensions on Database). That does a whole migration + reset just to render the SQL needlessly.
extension Database {
    func renderSQL(_ builder: SQLSelectBuilder) -> String {
        renderSQL(builder.query)
    }

    func renderSQL(_ query: SQLExpression) -> String {
        var serializer = SQLSerializer(database: self as! SQLDatabase)
        query.serialize(to: &serializer)
        return serializer.sql
    }

    func binds(_ builder: SQLSelectBuilder?) -> [String] {
        binds(builder?.query)
    }

    func binds(_ query: SQLExpression?) -> [String] {
        var serializer = SQLSerializer(database: self as! SQLDatabase)
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
