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

import Dependencies
import Plot


extension MaintainerInfoIndex {
    struct Model {
        var packageName: String
        var repositoryOwner: String
        var repositoryOwnerName: String
        var repositoryName: String
        var score: Int
        var scoreDetails: Score.Details?

        struct PackageScore {
            var title: String
            var score: Int
            var description: String
        }

        func badgeURL(for type: BadgeType) -> String {
            let characterSet = CharacterSet.urlHostAllowed.subtracting(.init(charactersIn: "=:"))
            let url = SiteURL.api(.packages(.value(repositoryOwner), .value(repositoryName), .badge)).absoluteURL(parameters: [QueryParameter(key: "type", value: type.rawValue)])
            let escaped = url.addingPercentEncoding(withAllowedCharacters: characterSet) ?? url
            return "https://img.shields.io/endpoint?url=\(escaped)"
        }

        func badgeMarkdown(for type: BadgeType) -> String {
            let spiPackageURL = SiteURL.package(.value(repositoryOwner), .value(repositoryName), .none).absoluteURL()
            return "[![](\(badgeURL(for: type)))](\(spiPackageURL))"
        }

        func badgeMarkdowDisplay(for type: BadgeType) -> Node<HTML.BodyContext> {
            .copyableInputForm(buttonName: "Copy Markdown",
                               eventName: "Copy Markdown Button",
                               valueToCopy: badgeMarkdown(for: type))
        }

        static func packageScoreCategories(for categories: [PackageScore]) -> Node<HTML.BodyContext> {
            return .forEach(0..<categories.count, { index in
                    .div(
                        .class("score-trait"),
                        .p("\(categories[index].title)"),
                        .p("\(categories[index].score) points"),
                        .p("\(categories[index].description)")
                    )
            })
        }

        var packageScoreDiscussionURL: String {
            "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/discussions/2591"
        }

        func scoreCategories() -> [PackageScore] {
            guard let scoreDetails else { return [] }
            return Score.Category.allCases
                .sorted { $0.title < $1.title }
                .compactMap { category in
                    PackageScore(title: category.title,
                                 score: scoreDetails.scoreBreakdown[category] ?? 0,
                                 description: scoreDetails.description(for: category))
                }
        }
    }
}

private extension Score.Category {
    var title: String {
        switch self {
            case .archive: return "Archived"
            case .license: return "License"
            case .releases: return "Releases"
            case .stars: return "Stars"
            case .dependencies: return "Dependencies"
            case .maintenance: return "Last Activity"
            case .documentation: return "Documentation"
            case .readme: return "README"
            case .contributors: return "Contributors"
            case .tests: return "Tests"
        }
    }
}


private extension Score.Details {
    func description(for category: Score.Category) -> String {
        switch category {
            case .archive:
                return "Repository is \(isArchived ? "" : "not") archived."
            case .license:
                return "\(licenseKind == .compatibleWithAppStore ? "" : "No ")OSI-compatible license which is compatible with the App Store."
            case .releases:
                return "Has \(pluralizedCount: releaseCount, singular: "release")."
            case .stars:
                return "Has \(pluralizedCount: likeCount, singular: "star")."
            case .dependencies:
                if let numberOfDependencies {
                    return "\(numberOfDependencies < 1 ? "Has no dependencies." : "Depends on \(pluralizedCount: numberOfDependencies, singular: "package", plural: "packages").")"
                } else {
                    return "No dependency information available."
                }
            case .maintenance:
                // Using 750 days as it's just more than two years, meaning it should be possible to say "Last maintenance activity two years ago".
                // The final nil-coalesce in this should never fire as it should always be possible to subtract two years from the current date.
                @Dependency(\.date.now) var now
                let maintainedRecently = lastActivityAt > Calendar.current.date(byAdding: .init(day: -750),
                                                                                to: now) ?? now
                return maintainedRecently
                ? "Last maintenance activity \(lastActivityAt.relative)."
                : "No recent maintenance activity."
            case .documentation:
                return "\(hasDocumentation ? "Includes " : "Has no") documentation."
            case .readme:
                return "\(hasReadme ? "Has a" : "Does not have a") README file."
            case .contributors:
                return "Has \(pluralizedCount: numberOfContributors, singular: "contributor")."
            case .tests:
                return "Has \(hasTestTargets ? "" : "no") test targets."
        }
    }
}
