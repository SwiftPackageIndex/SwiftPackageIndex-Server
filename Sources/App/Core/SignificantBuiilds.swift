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

struct SignificantBuilds {
    var builds: [Build]

    @available(*, deprecated)
    init(builds: [Build]) {
        self.builds = builds
    }

    init(versions: [Version]) {
        self.builds = [Version.Kind.release, .preRelease, .defaultBranch]
            .compactMap(versions.latest(for:))
            .reduce(into: []) {
                $0.append(contentsOf: $1.$builds.value ?? [])
            }
    }

    func allSatisfy(_ predicate: (Build) throws -> Bool) rethrows -> Bool {
        try builds.allSatisfy(predicate)
    }

    func filter(_ isIncluded: (Build) throws -> Bool) rethrows -> [Build] {
        try builds.filter(isIncluded)
    }

    // TODO: add tests
    static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<Self> {
#warning("use (platform, status) and (swiftVersion, status) pairs instead")
        return Build.query(on: database)
            .join(parent: \.$version)
            .join(Package.self, on: \App.Version.$package.$id == \Package.$id)
            .join(Repository.self, on: \Repository.$package.$id == \Package.$id)
            .filter(App.Version.self, \App.Version.$latest != nil)
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .filter(Repository.self, \.$name, .custom("ilike"), repository)
            .field(\.$platform)
            .field(\.$swiftVersion)
            .field(\.$status)
            .all()
            .map(Self.init(builds:))
    }
}
