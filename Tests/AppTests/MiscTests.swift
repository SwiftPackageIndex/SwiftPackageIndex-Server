@testable import App

import XCTest


/// Tests for utilities and extesions that don't each need a full separate test class
class MiscTests: XCTestCase {
    
    func test_Dictionary_queryString() throws {
        // basic
        XCTAssertEqual(["foo": "bar"].queryString(), "?foo=bar")
        // no separator
        XCTAssertEqual(["foo": "bar"].queryString(includeSeparator: false), "foo=bar")
        // sorting
        XCTAssertEqual(["b": "2", "a": "1"].queryString(), "?a=1&b=2")
        // query string encoding
        XCTAssertEqual(["foo bar": "1"].queryString(), "?foo%20bar=1")
        // empty
        XCTAssertEqual([String: String]().queryString(), "")
        XCTAssertEqual([String: String]().queryString(includeSeparator: false), "")
    }

    func test_Date_init_yyyyMMdd() throws {
        XCTAssertEqual(Date(yyyyMMdd: "1970-01-01"),
                       Date(timeIntervalSince1970: 0))
        XCTAssertEqual(Date(yyyyMMdd: "foo"), nil)
    }

    func test_Date_LosslessStringConvertible() throws {
        XCTAssertEqual(Date("1970-01-01"),
                       Date(timeIntervalSince1970: 0))
        XCTAssertEqual(Date("foo"), nil)
    }

}
