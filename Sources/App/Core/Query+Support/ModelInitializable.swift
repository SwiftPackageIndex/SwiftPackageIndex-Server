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

import FluentKit


// Ideally, this protocal wouldn't be necessary and the initialisers private,
// in order to prevent mis-use (instantiating a not properly populated Joined
// or Ref). However, this is not possible for reasons outlined here:
// https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/pull/1367#issue-1051671014
protocol ModelInitializable {
    associatedtype M: Model
    init(model: M)
}
