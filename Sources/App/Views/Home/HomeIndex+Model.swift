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

import Foundation

import Fluent
import Plot


extension HomeIndex {
    struct Model {
        var stats: Stats?
        var recentPackages: [DatedLink]
        var recentReleases: [Release]
        
        struct Release: Equatable {
            var packageName: String
            var version: String
            var date: String
            var url: String
        }
    }
}


extension HomeIndex.Model {
    static var numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.thousandSeparator = ","
        f.numberStyle = .decimal
        return f
    }()
    
    func statsDescription() -> String? {
        guard
            let stats = stats,
            let packageCount = Self.numberFormatter.string(from: NSNumber(value: stats.packageCount))
        else { return nil }
        return "\(packageCount) packages"
    }
    
    func statsClause() -> Node<HTML.BodyContext>? {
        guard let description = statsDescription() else { return nil }
        return .small(
            .text("Indexing "),
            .text(description)
        )
    }
    
    func recentPackagesSection() -> Node<HTML.ListContext> {
        .group(
            recentPackages.map { datedLink -> Node<HTML.ListContext> in
                .li(
                    .a(
                        .href(datedLink.link.url),
                        .text(datedLink.link.label)
                    ),
                    .small(.text("Added \(datedLink.date)"))
                )
            }
        )
    }
    
    func recentReleasesSection() -> Node<HTML.ListContext> {
        .group(
            recentReleases.map { release -> Node<HTML.ListContext> in
                .li(
                    .a(
                        .href(release.url),
                        .text("\(release.packageName) "),
                        .small(.text(release.version))
                    ),
                    .small(.text("Released \(release.date)"))
                )
            }
        )
    }
}
