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


public enum V1 { }

public enum Tier<V1>: String, Codable, CaseIterable, Sendable {
    case tier1         // search API only
    case tier2
    case tier3         // the above + package, package-collection API
    case tier4
    case `internal`    // the above + build reporting and other internal API
}

extension Tier: Comparable {
    var ordinal: Int { Tier.allCases.firstIndex(of: self)! }

    public static func < (lhs: Tier, rhs: Tier) -> Bool {
        lhs.ordinal < rhs.ordinal
    }
}
