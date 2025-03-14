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

import Foundation

@testable import App

import Testing


/// Tests for utilities and extesions that don't each need a full separate test class
extension AllTests.MiscTests {

    @Test func Array_queryString() throws {
        // Single parameter
        #expect([QueryParameter(key: "foo", value: "bar")].queryString() == "?foo=bar")

        // Multiple parameters
        #expect([
            QueryParameter(key: "foo", value: "bar"),
            QueryParameter(key: "baz", value: "erp")
        ].queryString() == "?foo=bar&baz=erp")

        // Single parameter without separator
        #expect([QueryParameter(key: "foo", value: "bar")].queryString(includeSeparator: false) == "foo=bar")
    }

    @Test func Date_init_yyyyMMdd() throws {
        #expect(Date("1970-01-01") == Date(timeIntervalSince1970: 0))
        #expect(Date("foo") == nil)
    }

    @Test func Date_iso8691() throws {
        #expect(Date("1970-01-01T0:01:23Z") == Date(timeIntervalSince1970: 83))
    }

    @Test func Date_LosslessStringConvertible() throws {
        #expect(Date("1970-01-01") == Date(timeIntervalSince1970: 0))
        #expect(Date("1970-01-01T0:01:23Z") == Date(timeIntervalSince1970: 83))
        #expect(Date("foo") == nil)
    }

}
