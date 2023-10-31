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
import Plot

typealias ScoreCategory = Score.ScoreDetails.ScoreCategory

extension MaintainerInfoIndex {
    struct Model {
        var packageName: String
        var repositoryOwner: String
        var repositoryOwnerName: String
        var repositoryName: String
        var score: Int
        var scoreDetails: Score.ScoreDetails
        
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
        
        func packageScoreCategories() -> Node<HTML.BodyContext> {
            .forEach(0..<scoreCategories.count, { index in
                    .div(
                        .class("score-trait"),
                        .p("\(scoreCategories[index].title)"),
                        .p("\(scoreCategories[index].score) points"),
                        .p("\(scoreCategories[index].description)")
                    )
            })
        }
        
        var packageScoreDiscussionURL: String {
            "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/discussions/2591"
        }
        
        var scoreCategories: [PackageScore] {
            let categories = Score.ScoreDetails.ScoreCategory.allCases.sorted { $0.title < $1.title }
            return categories.compactMap {
                let description = if let candidate = scoreDetails.candidate {
                    $0.description(candidate: candidate)
                } else {
                    "Unable to retrieve package input data."
                }
                return PackageScore(title: $0.title, score: scoreDetails.scoreBreakdown[$0] ?? 0, description: description)
            }
        }
    }
}

private extension Score.ScoreDetails.ScoreCategory {
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
    
    func description(candidate: Score.Input) -> String {
        switch self {
        case .archive:
            "Repository is \(candidate.isArchived ? "" : "not") archived."
        case .license:
            "\(candidate.licenseKind == .compatibleWithAppStore ? "" : "No ")OSI-compatible license which is compatible with the App Store."
        case .releases:
            "Has \(pluralizedCount: candidate.releaseCount, singular: "release")."
        case .stars:
            "Has \(pluralizedCount: candidate.likeCount, singular: "star")."
        case .dependencies:
            "\(candidate.numberOfDependencies ?? 0 < 1 ? "Has no dependencies." : "Depends on \(pluralizedCount: candidate.numberOfDependencies ?? 0, singular: "package", plural: "packages").")"
        case .maintenance:
            if candidate.lastActivityAt != nil { "The last maintenance activity was \(candidate.lastActivityAt?.relative)." } else { "No data available."}
        case .documentation:
            "\(candidate.hasDocumentation ? "Includes " : "Has no") documentation."
        case .readme:
            "\(candidate.hasReadme ? "Has a" : "Does not have a") README file."
        case .contributors:
            "Has \(pluralizedCount: candidate.numberOfContributors, singular: "contributor")."
        case .tests:
            "Has \(candidate.hasTestTargets ? "" : "no") test targets."
        }
    }
}
