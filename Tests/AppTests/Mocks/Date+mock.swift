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


extension Date {
    static let t0 = Date(timeIntervalSince1970: 0)
    static let t1 = Date(timeIntervalSince1970: 1)
    static let t2 = Date(timeIntervalSince1970: 2)
    static let t3 = Date(timeIntervalSince1970: 3)
    static let t4 = Date(timeIntervalSince1970: 4)
    static let spiBirthday = Date.init(rfc1123: "Sat, 25 Apr 2020 10:55:00 UTC")!
}


extension Date {
    func adding(days: Int? = nil, hours: Int? = nil, minutes: Int? = nil) -> Self {
        Calendar.current.date(byAdding: .init(day: days, hour: hours, minute: minutes), to: self)!
    }
}
