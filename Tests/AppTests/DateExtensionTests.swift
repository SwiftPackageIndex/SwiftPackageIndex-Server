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

import Dependencies
import Testing

extension AllTests.DateExtensionTests {

    @Test(arguments: [
        ("2021-04-01", "1st April 2021"),
        ("2021-04-02", "2nd April 2021"),
        ("2021-04-03", "3rd April 2021"),
        ("2021-04-04", "4th April 2021"),
    ])
    func ordinalLongDateString(input: String, expected: String) throws {
        try withDependencies {
            $0.timeZone = .utc
        } operation: {
            let fmt = DateFormatter.yearMonthDayDateFormatter
            let date = try #require(fmt.date(from: input))
            #expect(date.ordinalLongDateString == expected)
        }
    }

}
