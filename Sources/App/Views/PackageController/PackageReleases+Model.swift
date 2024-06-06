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

import Foundation
import Vapor
import SwiftSoup

extension PackageReleases {

    struct Model: Equatable {
        private static var dateFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMMM yyyy"
            return formatter
        }

        struct Release: Equatable {
            let title: String
            let date: String?
            let html: String?
            let link: String
        }

        let releases: [Release]

        internal init?(package: Joined<Package, Repository>) {
            guard let releases = package.repository?.releases,
                  releases.isEmpty == false
            else {
                return nil
            }

            self.releases = releases.map { release in
                Release(
                    title: release.tagName,
                    date: Self.formatDate(release.publishedAt),
                    html: Self.updateDescription(release.descriptionHTML, replacingTitle: release.tagName),
                    link: release.url
                )
            }
        }

        init(releases: [Release]) {
            self.releases = releases
        }

        static func formatDate(_ date: Date?, currentDate: Date = Current.date()) -> String? {
            guard let date = date else { return nil }
            return "Released \(date: date, relativeTo: currentDate) on \(Self.dateFormatter.string(from: date))"
        }

        static func updateDescription(_ description: String?, replacingTitle title: String) -> String? {
            guard let description = description?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !description.isEmpty
            else { return nil }

            do {
                // Some packages start their release notes with a large title reiterating the version number.
                // Since we already show this information prominently, we remove these titles.

                let htmlDocument = try SwiftSoup.parse(description)
                let headerElements = try htmlDocument.select("h1, h2, h3, h4, h5, h6")

                guard let titleHeader = headerElements.first()
                else { return description }

                if try titleHeader.text().contains(title) {
                    try titleHeader.remove()
                }

                return try htmlDocument.body()?.html()
            } catch {
                return description
            }
        }
    }
}
