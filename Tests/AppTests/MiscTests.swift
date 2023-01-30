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

@testable import App

import XCTest


/// Tests for utilities and extesions that don't each need a full separate test class
class MiscTests: XCTestCase {

    func test_Array_queryString() throws {
        // Single parameter
        XCTAssertEqual([QueryParameter(key: "foo", value: "bar")].queryString(), "?foo=bar")

        // Multiple parameters
        XCTAssertEqual([
            QueryParameter(key: "foo", value: "bar"),
            QueryParameter(key: "baz", value: "erp")
        ].queryString(), "?foo=bar&baz=erp")

        // Single parameter without separator
        XCTAssertEqual([QueryParameter(key: "foo", value: "bar")].queryString(includeSeparator: false), "foo=bar")
    }

    func test_Date_init_yyyyMMdd() throws {
        XCTAssertEqual(Date("1970-01-01"),
                       Date(timeIntervalSince1970: 0))
        XCTAssertEqual(Date("foo"), nil)
    }

    func test_Date_iso8691() throws {
        XCTAssertEqual(Date("1970-01-01T0:01:23Z"),
                       Date(timeIntervalSince1970: 83))
    }

    func test_Date_LosslessStringConvertible() throws {
        XCTAssertEqual(Date("1970-01-01"),
                       Date(timeIntervalSince1970: 0))
        XCTAssertEqual(Date("1970-01-01T0:01:23Z"),
                       Date(timeIntervalSince1970: 83))
        XCTAssertEqual(Date("foo"), nil)
    }

}
