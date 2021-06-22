import SQLKit
import XCTVapor


class AppTestCase: XCTestCase {
    var app: Application!

    func future<T>(_ value: T) -> EventLoopFuture<T> {
        app.eventLoopGroup.next().future(value)
    }
    
    func future<T>(error: Error) -> EventLoopFuture<T> {
        app.eventLoopGroup.next().future(error: error)
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        app = try setup(.testing)
    }
    
    override func tearDownWithError() throws {
        app.shutdown()
        try super.tearDownWithError()
    }
}


extension AppTestCase {
    func renderSQL(_ query: SQLSelectBuilder?, resolveBinds: Bool = false) -> String {
        renderSQL(query?.query, resolveBinds: resolveBinds)
    }

    func renderSQL(_ query: SQLExpression?, resolveBinds: Bool = false) -> String {
        var serializer = SQLSerializer(database: app.db as! SQLDatabase)
        query?.serialize(to: &serializer)
        var sql = serializer.sql
        if resolveBinds {
            for (idx, bind) in binds(query).enumerated() {
                sql = sql.replacingOccurrences(of: "$\(idx+1)", with: "'\(bind)'")
            }
        }
        return sql
    }

    func binds(_ query: SQLSelectBuilder?) -> [String] {
        binds(query?.query)
    }

    func binds(_ query: SQLExpression?) -> [String] {
        var serializer = SQLSerializer(database: app.db as! SQLDatabase)
        query?.serialize(to: &serializer)
        return serializer.binds as! [String]
    }
}
