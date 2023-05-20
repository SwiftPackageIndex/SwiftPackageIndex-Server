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
import Plot


extension HomeIndex.Model {
    static func query(database: Database) async throws -> Self {
        let stats = try await Stats.fetch(on: database).get()
        let packages = try await RecentPackage.fetch(on: database).map(makeDateLink)
        let releases = try await RecentRelease.fetch(on: database)
            .map(Release.init(recent:))
        return .init(stats: stats, recentPackages: packages, recentReleases: releases)
    }
}


extension HomeIndex.Model {
    static func makeLink(_ recent: RecentPackage) -> Link {
        return .init(label: recent.packageName,
                     url: SiteURL.package(.value(recent.repositoryOwner),
                                          .value(recent.repositoryName),
                                          .none).relativeURL())
    }

    static func makeDateLink(_ recent: RecentPackage) -> DateLink {
        let link = makeLink(recent)
        return .init(date: recent.createdAt, link: link)
    }
}


extension HomeIndex.Model.Release {
    init(recent: RecentRelease) {
        packageName = recent.packageName
        version = recent.version
        date = "\(date: recent.releasedAt, relativeTo: Current.date())"
        url = SiteURL.package(.value(recent.repositoryOwner),
                              .value(recent.repositoryName),
                              .none).relativeURL()
    }
}
