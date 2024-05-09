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


enum DocVersion: Codable, Equatable {
    case current(referencing: String? = nil)
    case reference(String)

    var reference: String {
        switch self {
            case .current(.none):
                return String.current
            case .current(.some(let reference)):
                return reference
            case .reference(let reference):
                return reference
        }
    }

    var pathEncoded: String {
        switch self {
            case .current: String.current
            case .reference( let reference): reference.pathEncoded
        }
    }
}


extension DocVersion: CustomStringConvertible {
    var description: String {
        switch self {
            case .current:
                return String.current
            case .reference(let string):
                return string
        }
    }
}
