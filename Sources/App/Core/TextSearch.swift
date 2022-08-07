// Copyright 2020-2022 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import SQLKit


enum TextSearch {

    enum Weight: String {
        case a  // 1.0 multiplier
        case b  // 0.4 multiplier
        case c  // 0.2 multiplier
        case d  // 0.1 multiplier
    }

    static func toVector(_ array: SQLExpression, weight: Weight = .d) -> SQLFunction {
        // The argument is meant to be a string, which this wraps and converts
        // first into a tsvector internal type, and then applies weighting
        // for query ranking purposes.
        // Details of the setweight function (and to_tsvector) are available
        // at https://www.postgresql.org/docs/current/textsearch-controls.html
        // The weight class 'A' results in a 1.0 multiplier on the rank.
        // The default weight class ('D') results in a  0.1 multiplier on the rank.
        SQLFunction("setweight", args: [to_tsvector(array), weight])
    }

}


extension TextSearch.Weight: SQLExpression {
    func serialize(to serializer: inout SQLKit.SQLSerializer) {
        SQLRaw("'\(rawValue.uppercased())'").serialize(to: &serializer)
    }
}
