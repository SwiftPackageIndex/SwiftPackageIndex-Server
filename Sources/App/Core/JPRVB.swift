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


/// A joined Package - Repository model with loaded versions and builds
struct JPRVB {
    var jpr: JPR

    var model: Package { jpr.model }
    var repository: Repository? { jpr.repository }
    var versions: [Version] { jpr.model.versions }
}


extension JPRVB {
    static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<JPRVB> {
        Joined<Package, Repository>.query(on: database)
            .with(\.$versions) {
                $0.with(\.$products)
                $0.with(\.$builds)
            }
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .filter(Repository.self, \.$name, .custom("ilike"), repository)
            .first()
            .unwrap(or: Abort(.notFound))
            .map(JPRVB.init(jpr:))
    }
}
