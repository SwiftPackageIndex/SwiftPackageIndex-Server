// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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


protocol Referencable {}

extension Joined: Referencable {}

extension Build: Referencable {}
extension Product: Referencable {}
extension Version: Referencable {}


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
struct Ref<M: Referencable, R: Referencable>: Referencable {
    private(set) var model: M
}


struct Ref2<M: Referencable, R1: Referencable, R2: Referencable>: Referencable {
    private(set) var model: M
}
