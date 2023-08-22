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


extension DateFormatter {
    static let lastUpdatedOnDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = .init(identifier: "en_GB")
        return formatter
    }()
    
    static let timeTagDateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = .init(identifier: "en_GB")
        return formatter
    }()
}


// LosslessStringConvertible conformance is required by @Option command line argument conversion
extension Date: LosslessStringConvertible {
    private static let iso8601: ISO8601DateFormatter = ISO8601DateFormatter()
    private static let ymd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

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
    var relative: String { "\(date: self, relativeTo: Current.date())" }
}
