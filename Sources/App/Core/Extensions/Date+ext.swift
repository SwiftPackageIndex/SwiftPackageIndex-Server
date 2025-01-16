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
import Dependencies


extension DateFormatter {
    static var mediumDateFormatter: DateFormatter {
        @Dependency(\.timeZone) var timeZone
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = .init(identifier: "en_GB")
        formatter.timeZone = timeZone
        return formatter
    }

    static var longDateFormatter: DateFormatter {
        @Dependency(\.timeZone) var timeZone
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = .init(identifier: "en_GB")
        formatter.timeZone = timeZone
        return formatter
    }

    static var yearMonthDayDateFormatter: DateFormatter {
        @Dependency(\.timeZone) var timeZone
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = .init(identifier: "en_GB")
        formatter.timeZone = timeZone
        return formatter
    }

    static var utcFullDateTimeDateFormatter: DateFormatter {
        // Note that this date formatter shows the time as UTC for
        // dates/times relative to Swift Package Index infrastructure.
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}


// LosslessStringConvertible conformance is required by @Option command line argument conversion
extension Date: Swift.LosslessStringConvertible {
    private static var iso8601: ISO8601DateFormatter { ISO8601DateFormatter() }
    private static var ymd: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = .utc
        return formatter
    }

    public init?(_ string: String) {
        if let date = Self.ymd.date(from: string) {
            self = date
            return
        }
        if let date = Self.iso8601.date(from: string) {
            self = date
            return
        }
        return nil
    }
}


extension Date {
    var relative: String {
        @Dependency(\.date.now) var now
        return "\(date: self, relativeTo: now)"
    }
}
