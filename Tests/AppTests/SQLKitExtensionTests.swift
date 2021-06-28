@testable import App

import SQLKit
import XCTest


class SQLKitExtensionTests: AppTestCase {

    // TODO: remove once once https://github.com/vapor/sql-kit/pull/133 has been merged
    func test_union_two_arguments() throws {
        let db = app.db as! SQLDatabase
        let union = db.union(
            db.select()
                .column("id")
                .from("t1")
                .where("f1", .equal, "foo")
                .limit(2),
            db.select()
                .column("id")
                .from("t2")
                .where("f2", .equal, "bar")
                .limit(3)
        )
        XCTAssertEqual(renderSQL(union.query),
                       #"(SELECT "id" FROM "t1" WHERE "f1" = $1 LIMIT 2) UNION (SELECT "id" FROM "t2" WHERE "f2" = $2 LIMIT 3)"#)
    }

    // TODO: remove once once https://github.com/vapor/sql-kit/pull/133 has been merged
    func test_union_multiple_arguments() throws {
        let db = app.db as! SQLDatabase
        let union = db.union(
            db.select().column("id").from("t1"),
            db.select().column("id").from("t2"),
            db.select().column("id").from("t3")
        )
        XCTAssertEqual(renderSQL(union.query),
                       #"(SELECT "id" FROM "t1") UNION (SELECT "id" FROM "t2") UNION (SELECT "id" FROM "t3")"#)
    }

    func test_OrderByGroup() throws {
        let b = SQLOrderBy(SQLIdentifier("id"), .ascending)
            .then(SQLIdentifier("foo"), .descending)
        XCTAssertEqual(renderSQL(b), #""id" ASC, "foo" DESC"#)
    }

    func test_OrderByGroup_complex() throws {
        let packageName = SQLIdentifier("package_name")
        let mergedTerms = SQLBind("a b")
        let score = SQLIdentifier("score")

        let orderBy = SQLOrderBy(eq(lower(packageName), mergedTerms), .descending)
            .then(score, .descending)
            .then(packageName, .ascending)
        XCTAssertEqual(renderSQL(orderBy),
                       #"LOWER("package_name") = $1 DESC, "score" DESC, "package_name" ASC"#)
    }

}
