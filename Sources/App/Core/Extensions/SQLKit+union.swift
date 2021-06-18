// TODO: remove this whole file once https://github.com/vapor/sql-kit/pull/133 has been merged

import SQLKit


public final class SQLUnionBuilder: SQLQueryBuilder {
    public var query: SQLExpression {
        return self.union
    }

    public var union: SQLUnion
    public var database: SQLDatabase

    public init(on database: SQLDatabase, _ args: [SQLSelectBuilder]) {
        self.union = .init(args.map { $0.select })
        self.database = database
    }
}

extension SQLDatabase {
    public func union(_ args: SQLSelectBuilder...) -> SQLUnionBuilder {
        SQLUnionBuilder(on: self, args)
    }
}


public struct SQLUnion: SQLExpression {
    public let args: [SQLExpression]

    public init(_ args: SQLExpression...) {
        self.init(args)
    }

    public init(_ args: [SQLExpression]) {
        self.args = args
    }

    public func serialize(to serializer: inout SQLSerializer) {
        let args = args.map(SQLGroupExpression.init)
        guard let first = args.first else { return }
        first.serialize(to: &serializer)
        for arg in args.dropFirst() {
            serializer.write(" UNION ")
            arg.serialize(to: &serializer)
        }
    }
}

