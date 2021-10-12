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

import FluentKit


// TODO: remove (or rename)
typealias JPR = Joined<Package, Repository>


extension Joined where M == Package, R == Repository {
    var repository: Repository? { relation }

    static func query(on database: Database) -> JoinedQueryBuilder<Joined> {
        query(on: database,
              join: \Repository.$package.$id == \Package.$id,
              // TODO: review this properly
              method: .left)
    }
}


extension Joined where M == Package, R == Repository {
    func findSignificantReleases(_ versions: [Version]) -> (release: Version?, preRelease: Version?, defaultBranch: Version?) {
        guard !versions.isEmpty else { return (nil, nil, nil) }
        let release = Package.findRelease(versions)
        let preRelease = Package.findPreRelease(versions, after: release?.reference)
        let defaultBranch = findDefaultBranchVersion(versions)
        return (release, preRelease, defaultBranch)
    }

    func findDefaultBranchVersion(_ versions: [Version]) -> Version? {
        guard
            !versions.isEmpty,
            let defaultBranch = repository?.defaultBranch
        else { return nil }
        return versions.first(where: { v in
            guard let ref = v.reference else { return false }
            switch ref {
                case .branch(let b) where b == defaultBranch:
                    return true
                default:
                    return false
            }
        })
    }
}
