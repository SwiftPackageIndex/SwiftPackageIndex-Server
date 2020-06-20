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

}
