// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Foundation
import XCTest


class DefaultStringInterpolationTests: XCTestCase {
    
    func test_inWords_timeDifference() throws {
        let m = 60
        let H = 60*m
        let d = 24*H
        let M = 30*d   // crude...
        let Y = 365*d  // ignore leap years
        let tests: [(Int, String)] = [
            (0, "0 seconds"),
            (15, "less than a minute"),
            (50, "1 minute"),
            (23*m, "23 minutes"),
            (50*m, "1 hour"),
            (1*H + 20*m, "1 hour"),
            (3*H, "3 hours"),
            (23*H, "23 hours"),
            (1*d + 3*H, "1 day"),
            (15*d, "15 days"),
            (1*M + 10*d, "about 1 month"),
            (5*M, "5 months"),
            (11*M, "11 months"),
            (1*Y + 3*M, "over 1 year"),
            (5*Y + 3*M, "5 years"),
        ]
        for (delta, exp) in tests {
            XCTAssertEqual("\(inWords: TimeInterval(delta))", exp, "delta was: \(delta)")
        }
    }
    
    func test_relativeDate_interpolation() throws {
        let now = Date()
        XCTAssertEqual("\(date: now.addingTimeInterval(5), relativeTo: now)", "in less than a minute")
        XCTAssertEqual("\(date: now.addingTimeInterval(-5), relativeTo: now)", "less than a minute ago")
    }
    
    func test_kiloPostfixedQuantity_interpolation() throws {
        XCTAssertEqual("\(kiloPostfixedQuantity: 1)", "1")
        XCTAssertEqual("\(kiloPostfixedQuantity: 10)", "10")
        XCTAssertEqual("\(kiloPostfixedQuantity: 100)", "100")
        XCTAssertEqual("\(kiloPostfixedQuantity: 1000)", "1.0k")
        XCTAssertEqual("\(kiloPostfixedQuantity: 1449)", "1.4k")
        XCTAssertEqual("\(kiloPostfixedQuantity: 1450)", "1.5k")
        XCTAssertEqual("\(kiloPostfixedQuantity: 1500)", "1.5k")
        XCTAssertEqual("\(kiloPostfixedQuantity: 9949)", "9.9k")
        XCTAssertEqual("\(kiloPostfixedQuantity: 9950)", "10.0k")
        XCTAssertEqual("\(kiloPostfixedQuantity: 9951)", "10.0k")
        XCTAssertEqual("\(kiloPostfixedQuantity: 10000)", "10.0k")
        
        XCTAssertEqual("\(kiloPostfixedQuantity: 12345)", "12.3k")
        XCTAssertEqual("\(kiloPostfixedQuantity: 54321)", "54.3k")
        XCTAssertEqual("\(kiloPostfixedQuantity: 123456)", "123.5k")
        XCTAssertEqual("\(kiloPostfixedQuantity: 654321)", "654.3k")
        
        XCTAssertEqual("\(kiloPostfixedQuantity: 0)", "0")
    }
}
