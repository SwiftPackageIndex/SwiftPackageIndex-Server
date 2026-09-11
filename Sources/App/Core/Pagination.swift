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


enum Pagination {
    /// Bounds for user supplied pagination parameters. Clamping to these ranges caps query cost and
    /// keeps the `offset`/`limit` arithmetic derived from them from overflowing.
    static let pageRange = 1...1_000
    static let pageSizeRange = 1...1_024
}
