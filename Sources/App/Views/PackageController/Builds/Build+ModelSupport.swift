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


extension Build {

    static func query(on database: Database, buildId: Build.Id) -> EventLoopFuture<Build> {
        Build.query(on: database)
            .filter(\.$id == buildId)
            .with(\.$version) {
                $0.with(\.$package) {
                    $0.with(\.$repositories)
                }
            }
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { build in
                // load all versions in order to resolve package name
                build.version.package.$versions.load(on: database).map { build }
            }
    }

}
