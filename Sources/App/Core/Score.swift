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

enum Score {
    struct Input {
        var licenseKind: License.Kind
        var releaseCount: Int
        var likeCount: Int
        var isArchived: Bool
        var numberOfDependencies: Int?
        var lastActivityAt: Date?
        var hasDocumentation: Bool
        var hasReadme: Bool
        var numberOfContributors: Int
        var hasTestTargets: Bool
    }
    
    struct ScoreDetails {
        enum ScoreCategory: CaseIterable {
            case archive
            case license
            case releases
            case stars
            case dependencies
            case maintenance
            case documentation
            case readme
            case contributors
            case tests
        }

        var candidate: Input?
        var scoreBreakdown: [ScoreCategory: Int]
        var score: Int {
            return scoreBreakdown.compactMap { $0.value }.reduce(0, +)
        }
    }

    static func compute(_ candidate: Input) -> ScoreDetails {
        var scoreBreakdown: [ScoreDetails.ScoreCategory: Int] = [:]
        
        // Is the package archived and no longer receiving updates?
        if candidate.isArchived == false {
            scoreBreakdown[.archive] = 20
        }

        // Is the license open-source and compatible with the App Store?
        switch candidate.licenseKind {
            case .compatibleWithAppStore:
                scoreBreakdown[.license] = 10
            case .incompatibleWithAppStore:
                scoreBreakdown[.license] = 3
            default: break;
        }

        // Number of releases
        switch candidate.releaseCount {
            case  ..<5:
                break
            case 5..<20:
                scoreBreakdown[.releases] = 10
            default:
                scoreBreakdown[.releases] = 20
        }

        // Stars count
        switch candidate.likeCount {
            case      ..<25    :
                break
            case    25..<100   :
                scoreBreakdown[.stars] = 10
            case   100..<500   :
                scoreBreakdown[.stars] = 20
            case   500..<5_000 :
                scoreBreakdown[.stars] = 30
            case 5_000..<10_000:
                scoreBreakdown[.stars] = 35
            default:
                scoreBreakdown[.stars] = 37
        }

        // Number of resolved dependencies
        switch candidate.numberOfDependencies {
            case .some(..<3):
                scoreBreakdown[.dependencies] = 5
            case .some(3..<5):
                scoreBreakdown[.dependencies] = 2
            default: break
        }

        // Last maintenance activity
        if let lastActivityAt = candidate.lastActivityAt {
            // Note: This is not the most accurate method to calculate the number of days between
            // two dates, but is more than good enough for the purposes of this calculation.
            let dateDifference = Calendar.current.dateComponents([.day], from: lastActivityAt, to: Current.date())
            switch dateDifference.day {
                case .some(..<30) :
                    scoreBreakdown[.maintenance] = 15
                case .some(30..<180) :
                    scoreBreakdown[.maintenance] = 10
                case .some(180..<360) :
                    scoreBreakdown[.maintenance] = 5
                default: break
            }
        }

        if candidate.hasDocumentation {
            scoreBreakdown[.documentation] = 15
        }
        
        if candidate.hasReadme {
            scoreBreakdown[.readme] = 15
        }

        switch candidate.numberOfContributors {
            case   ..<5: break
            case 5..<20:
                scoreBreakdown[.contributors] = 5
            default:
                scoreBreakdown[.contributors] = 10
        }
        
        if candidate.hasTestTargets { scoreBreakdown[.tests] = 5 }

        let scoreDetails = ScoreDetails(candidate: candidate, scoreBreakdown: scoreBreakdown)
        return scoreDetails
    }

    static func compute(repo: Repository?, versions: [Version], targets: [(String, TargetType)]? = []) -> ScoreDetails {
        guard
            let defaultVersion = versions.latest(for: .defaultBranch),
            let repo
        else { return ScoreDetails(candidate: nil, scoreBreakdown: [:]) }

        let hasDocumentation = [
            defaultVersion,
            versions.latest(for: .release),
            versions.latest(for: .preRelease)
        ].hasDocumentation()

        let numberOfContributors = {
            guard let authors = repo.authors else { return 0 }
            return authors.authors.count + authors.numberOfContributors
        }()
        
        let hasTestTargets = !(targets?.filter { $0.1 == App.TargetType.test }.isEmpty ?? false)
        
        return Score.compute(
            .init(licenseKind: repo.license.licenseKind,
                  releaseCount: versions.releases.count,
                  likeCount: repo.stars,
                  isArchived: repo.isArchived,
                  numberOfDependencies: defaultVersion.resolvedDependencies?.count,
                  lastActivityAt: repo.lastActivityAt,
                  hasDocumentation: hasDocumentation,
                  hasReadme: repo.readmeHtmlUrl != nil,
                  numberOfContributors: numberOfContributors,
                  hasTestTargets: hasTestTargets
            )
        )
    }
}


private extension Array where Element == Version {
    func latest(for kind: Version.Kind) -> Version? {
        first { $0.latest == kind }
    }

    var releases: Self { filter { $0.reference.isTag } }
}
