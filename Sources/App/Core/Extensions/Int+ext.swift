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


extension Int {

    func labeled(_ singular: String, plural: String? = nil, capitalized: Bool = false, numberFormatter: NumberFormatter = .spiDefault) -> String {
        "\(pluralizedCount: self, singular: singular, plural: plural, capitalized: capitalized, numberFormatter: numberFormatter)"
    }

}
