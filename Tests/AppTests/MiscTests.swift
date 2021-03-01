@testable import App

import XCTest


/// Tests for utilities and extesions that don't each need a full separate test class
class MiscTests: XCTestCase {
    
    func test_Array_queryString() throws {
        // basic with string value
        XCTAssertEqual([QueryStringParameter(key: "foo", value: "bar")].queryString(), "?foo=bar")
        // no separator
        XCTAssertEqual([QueryStringParameter(key: "foo", value: "bar")].queryString(includeSeparator: false), "foo=bar")
        // multiple parameters and integer value
        XCTAssertEqual([QueryStringParameter(key: "b", value: 2), QueryStringParameter(key: "a", value: 1)].queryString(), "?b=2&a=1")
        // query string encoding
        XCTAssertEqual([QueryStringParameter(key: "foo bar", value: 1)].queryString(), "?foo%20bar=1")
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
