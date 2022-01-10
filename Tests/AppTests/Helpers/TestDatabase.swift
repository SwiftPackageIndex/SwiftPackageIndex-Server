// Copied from https://github.com/vapor/sql-kit/blob/main/Tests/SQLKitTests/Utilities.swift#L4
// in order to render SQL without an active db handle.

import SQLKit
import NIO

final class TestDatabase: SQLDatabase {
    let logger: Logger
    let eventLoop: EventLoop
    var results: [String]
    var bindResults: [[Encodable]]
    var dialect: SQLDialect {
        self._dialect
    }
    var _dialect: GenericDialect

    init() {
        self.logger = .init(label: "codes.vapor.sql.test")
        self.eventLoop = EmbeddedEventLoop()
        self.results = []
        self.bindResults = []
        self._dialect = GenericDialect()
    }

    func execute(sql query: SQLExpression, _ onRow: @escaping (SQLRow) -> ()) -> EventLoopFuture<Void> {
        var serializer = SQLSerializer(database: self)
        query.serialize(to: &serializer)
        results.append(serializer.sql)
        bindResults.append(serializer.binds)
        return self.eventLoop.makeSucceededFuture(())
    }
}

struct TestRow: SQLRow {
    enum Datum { // yes, this is just Optional by another name
        case some(Encodable)
        case none
    }

    var data: [String: Datum]

    enum _Error: Error {
        case missingColumn(String)
        case typeMismatch(Any, Any.Type)
    }

    var allColumns: [String] {
        .init(self.data.keys)
    }

    func contains(column: String) -> Bool {
        self.data.keys.contains(column)
    }

    func decodeNil(column: String) throws -> Bool {
        if case .some(.none) = self.data[column] { return true }
        return false
    }

    func decode<D>(column: String, as type: D.Type) throws -> D
        where D : Decodable
    {
        guard case let .some(.some(value)) = self.data[column] else {
            throw _Error.missingColumn(column)
        }
        guard let cast = value as? D else {
            throw _Error.typeMismatch(value, D.self)
        }
        return cast
    }
}

struct GenericDialect: SQLDialect {
    var name: String { "generic" }

    func bindPlaceholder(at position: Int) -> SQLExpression { SQLRaw("$\(position)") }
    func literalBoolean(_ value: Bool) -> SQLExpression { SQLRaw("\(value)") }
    var supportsAutoIncrement: Bool = true
    var supportsIfExists: Bool = true
    var supportsReturning: Bool = true
    var identifierQuote: SQLExpression = SQLRaw("`")
    var literalStringQuote: SQLExpression = SQLRaw("'")
    var enumSyntax: SQLEnumSyntax = .inline
    var autoIncrementClause: SQLExpression = SQLRaw("AUTOINCREMENT")
    var autoIncrementFunction: SQLExpression? = nil
    var supportsDropBehavior: Bool = false
    var triggerSyntax = SQLTriggerSyntax(create: [], drop: [])
    var alterTableSyntax = SQLAlterTableSyntax(alterColumnDefinitionClause: SQLRaw("MODIFY"), alterColumnDefinitionTypeKeyword: nil)
    var upsertSyntax: SQLUpsertSyntax = .standard
    var unionFeatures: SQLUnionFeatures = []

    mutating func setTriggerSyntax(create: SQLTriggerSyntax.Create = [], drop: SQLTriggerSyntax.Drop = []) {
        self.triggerSyntax.create = create
        self.triggerSyntax.drop = drop
    }
}

