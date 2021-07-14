import SQLKit
import XCTVapor
@testable import App

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
    func renderSQL(_ builder: SQLSelectBuilder?, resolveBinds: Bool = false) -> String {
        renderSQL(builder?.query, resolveBinds: resolveBinds)
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

    func binds(_ builder: SQLSelectBuilder?) -> [String] {
        binds(builder?.query)
    }

    func binds(_ query: SQLExpression?) -> [String] {
        var serializer = SQLSerializer(database: app.db as! SQLDatabase)
        query?.serialize(to: &serializer)
        return serializer.binds.reduce(into: []) { result, bind in
            if let bind = bind as? String { result.append(bind) }
            if let bind = bind as? Date { result.append(LastCommitSearchFilter.dateFormatter.string(from: bind)) }
            if let bind = bind as? Int { result.append(String(bind)) }
        }
    }
}
