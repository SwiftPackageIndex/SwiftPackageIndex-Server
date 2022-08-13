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
import Plot


extension HomeIndex.Model {
    static func query(database: Database) -> EventLoopFuture<Self> {
        let stats = Stats.fetch(on: database)
        let packages = RecentPackage.fetch(on: database).mapEach(makeDatedLink)
        let releases = RecentRelease.fetch(on: database).mapEach(Release.init(recent:))
        return stats.and(packages).and(releases)
            .map { ($0.0, $0.1, $1) }
            .map(Self.init)
    }
}


extension HomeIndex.Model {
    static func makeLink(_ recent: RecentPackage) -> Link {
        return .init(label: recent.packageName,
                     url: SiteRoute.relativeURL(for: .package(owner: recent.repositoryOwner, repository: recent.repositoryName)))
    }
    
    static func makeDatedLink(_ recent: RecentPackage) -> DatedLink {
        let link = makeLink(recent)
        return .init(date: "\(date: recent.createdAt, relativeTo: Current.date())", link: link)
    }
}


extension HomeIndex.Model.Release {
    init(recent: RecentRelease) {
        packageName = recent.packageName
        version = recent.version
        date = "\(date: recent.releasedAt, relativeTo: Current.date())"
        url = SiteRoute.relativeURL(for: .package(owner: recent.repositoryOwner, repository: recent.repositoryName))
    }
}
