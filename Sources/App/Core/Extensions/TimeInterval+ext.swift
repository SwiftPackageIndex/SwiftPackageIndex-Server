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


extension TimeInterval {
    static func days(_ value: Double) -> Self { value * .hours(24) }
    static func hours(_ value: Double) -> Self { value * .minutes(60) }
    static func minutes(_ value: Double) -> Self { value * .seconds(60) }
    static func seconds(_ value: Double) -> Self { value }

    var inHours: Double { inMinutes/60 }
    var inMinutes: Double { self/60 }
}
