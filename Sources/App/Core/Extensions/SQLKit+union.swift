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

// TODO: remove this whole file once https://github.com/vapor/sql-kit/pull/133 has been merged

import SQLKit


public final class SQLUnionBuilder: SQLQueryBuilder {
    public var query: SQLExpression {
        return self.union
    }

    public var union: SQLUnion
    public var database: SQLDatabase

    public init(on database: SQLDatabase,
                _ args: [SQLSelectBuilder],
                all: Bool = false) {
        self.union = .init(args.map(\.select), all: all)
        self.database = database
    }
}

extension SQLDatabase {
    public func union(_ args: SQLSelectBuilder...) -> SQLUnionBuilder {
        SQLUnionBuilder(on: self, args)
    }

    public func unionAll(_ args: SQLSelectBuilder...) -> SQLUnionBuilder {
        SQLUnionBuilder(on: self, args, all: true)
    }
}


public struct SQLUnion: SQLExpression {
    public let args: [SQLExpression]
    public let all: Bool

    public init(_ args: SQLExpression..., all: Bool = false) {
        self.init(args, all: all)
    }

    public init(_ args: [SQLExpression], all: Bool = false) {
        self.args = args
        self.all = all
    }

    public func serialize(to serializer: inout SQLSerializer) {
        let args = args.map(SQLGroupExpression.init)
        guard let first = args.first else { return }
        first.serialize(to: &serializer)
        for arg in args.dropFirst() {
            serializer.write(all ? " UNION ALL " : " UNION ")
            arg.serialize(to: &serializer)
        }
    }
}

