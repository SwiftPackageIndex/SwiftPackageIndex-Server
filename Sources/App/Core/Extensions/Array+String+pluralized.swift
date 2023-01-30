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


extension Array where Element == String {
    func pluralized() -> String {
        switch count {
            case 0:
                return "None"
            case 1:
                return first!
            case 2:
                return "\(first!) and \(last!)"
            default:
                return dropLast().joined(separator: ", ") + ", and \(last!)"
        }
    }
}
