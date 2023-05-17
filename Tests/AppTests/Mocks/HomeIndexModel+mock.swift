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

@testable import App


extension HomeIndex.Model {
    static var mock: HomeIndex.Model {
        .init(
            stats: .init(packageCount: 2544),
            recentPackages: [
                .init(date: Current.date().adding(hours: -2),
                      link: .init(label: "Package", url: "https://example.com/package")),
                .init(date: Current.date().adding(hours: -2),
                      link: .init(label: "Package", url: "https://example.com/package")),
                .init(date: Current.date().adding(hours: -2),
                      link: .init(label: "Package", url: "https://example.com/package")),
                .init(date: Current.date().adding(hours: -2),
                      link: .init(label: "Package", url: "https://example.com/package")),
                .init(date: Current.date().adding(hours: -2),
                      link: .init(label: "Package", url: "https://example.com/package")),
                .init(date: Current.date().adding(hours: -2),
                      link: .init(label: "Package", url: "https://example.com/package")),
            ],
            recentReleases: [
                .init(packageName: "Package", version: "1.0.0", date: "20 minutes ago", url: "https://example.com/package"),
                .init(packageName: "Package", version: "1.0.0", date: "20 minutes ago", url: "https://example.com/package"),
                .init(packageName: "Package", version: "1.0.0", date: "20 minutes ago", url: "https://example.com/package"),
                .init(packageName: "Package", version: "1.0.0", date: "20 minutes ago", url: "https://example.com/package"),
                .init(packageName: "Package", version: "1.0.0", date: "20 minutes ago", url: "https://example.com/package"),
                .init(packageName: "Package", version: "1.0.0", date: "20 minutes ago", url: "https://example.com/package"),
            ])
    }
}
