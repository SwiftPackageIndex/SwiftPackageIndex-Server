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
import SQLKit
import Vapor


extension PackageController {
    typealias PackageResult = Joined5<Package, Repository, DefaultVersion, ReleaseVersion, PreReleaseVersion>
}


extension PackageController.PackageResult {
    var package: Package { model }
    // We can force-unwrap due to the inner join
    var repository: Repository { relation1! }
    // We can force-unwrap due to the inner join
    var defaultBranchVersion: DefaultVersion { relation2! }
    var releaseVersion: ReleaseVersion? { relation3 }
    var preReleaseVersion: PreReleaseVersion? { relation4 }

    #warning("only load required fields (TODO below)")
    static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<Self> {
        Package.query(on: database)
            .join(Repository.self,
                  on: \Repository.$package.$id == \Package.$id,
                  method: .inner)
            .join(DefaultVersion.self,
                  on: \DefaultVersion.$package.$id == \Package.$id,
                  method: .inner)
            .join(Package.self, ReleaseVersion.self,
                  on: .custom(#"""
                    LEFT JOIN "\#(Version.schema)" AS "\#(ReleaseVersion.name)"
                    ON "\#(Package.schema)"."id" = "\#(ReleaseVersion.name)"."package_id"
                    AND "\#(ReleaseVersion.name)"."latest" = 'release'
                    """#)
            )
            .join(Package.self, PreReleaseVersion.self,
                  on: .custom(#"""
                    LEFT JOIN "\#(Version.schema)" AS "\#(PreReleaseVersion.name)"
                    ON "\#(Package.schema)"."id" = "\#(PreReleaseVersion.name)"."package_id"
                    AND "\#(PreReleaseVersion.name)"."latest" = 'pre_release'
                    """#)
            )
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .filter(Repository.self, \.$name, .custom("ilike"), repository)
            .filter(DefaultVersion.self, \.$latest == .defaultBranch)
        // TODO: only load required fields
            .first()
            .unwrap(or: Abort(.notFound))
            .map(Self.init(model:))
    }
}


final class DefaultVersion: ModelAlias {
    static let name = "default_version"
    let model = Version()
}

final class ReleaseVersion: ModelAlias {
    static let name = "release_version"
    let model = Version()
}

final class PreReleaseVersion: ModelAlias {
    static let name = "pre_release_version"
    let model = Version()
}


