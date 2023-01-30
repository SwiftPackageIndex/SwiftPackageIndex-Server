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

import Fluent
import Vapor


protocol Referenceable {}

extension Joined: Referenceable {}
extension Joined3: Referenceable {}

extension Build: Referenceable {}
extension Package: Referenceable {}
extension Product: Referenceable {}
extension Repository: Referenceable {}
extension Target: Referenceable {}
extension Version: Referenceable {}


/// `Ref` and `Ref2`, together with `Joined` allow us to define typed query results
/// that encode the query structure in the type. This is important to avoid
/// triggering fatal errors when accessing relationships that have not been
/// loaded. Result types based in these containers can expose accessors that are
/// safe.
/// An example use case is `PackageController.PackageResult`, which is a
/// typealias of `Ref<Joined<Package, Repository>, Ref2<Version, Build, Product>>`,
/// representing the following query result:
/// ```
/// (Package - Repository) -< Version
///                              |
///                              |-< Build
///                              |
///                              '-< Product
/// ```
// periphery:ignore
struct Ref<M: Referenceable, R: Referenceable>: Referenceable {
    private(set) var model: M
}


// periphery:ignore
struct Ref2<M: Referenceable, R1: Referenceable, R2: Referenceable>: Referenceable {
    private(set) var model: M
}


// periphery:ignore
struct Ref3<M: Referenceable, R1: Referenceable, R2: Referenceable, R3: Referenceable>: Referenceable {
    private(set) var model: M
}
