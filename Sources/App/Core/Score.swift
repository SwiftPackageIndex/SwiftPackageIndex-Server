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

enum Score {
    struct Input {
        var licenseKind: License.Kind
        var releaseCount: Int
        var likeCount: Int
        var isArchived: Bool
        var numberOfDependencies: Int?
        var lastActivityAt: Date?
        var hasDocumentation: Bool
    }
    
    static func compute(_ candidate: Input) -> Int {
        var score = 0
        
        // Is the package archived and no longer receiving updates?
        if candidate.isArchived == false { score += 20 }
        
        // Is the license open-source and compatible with the App Store?
        switch candidate.licenseKind {
            case .compatibleWithAppStore: score += 10
            case .incompatibleWithAppStore: score += 3
            default: break;
        }
        
        // Number of releases
        switch candidate.releaseCount {
            case  ..<5 :   break
            case 5..<20:   score += 10
            default    :   score += 20
        }
        
        // Stars count
        switch candidate.likeCount {
            case      ..<25    :  break
            case    25..<100   :  score += 10
            case   100..<500   :  score += 20
            case   500..<5_000 :  score += 30
            case 5_000..<10_000:  score += 35
            default:              score += 37
        }

        // Number of resolved dependencies
        switch candidate.numberOfDependencies {
            case .some(..<3): score += 5
            case .some(3..<5): score += 2
            default: break
        }

        // Last maintenance activity
        if let lastActivityAt = candidate.lastActivityAt {
            // Note: This is not the most accurate method to calculate the number of days between
            // two dates, but is more than good enough for the purposes of this calculation.
            let dateDifference = Calendar.current.dateComponents([.day], from: lastActivityAt, to: Current.date())
            switch dateDifference.day {
                case .some(..<30) : score += 15
                case .some(30..<180) : score += 10
                case .some(180..<360) : score += 5
                default: break
            }
        }

        if candidate.hasDocumentation {
            score += 15
        }

        return score
    }

    static func compute(package: Joined<Package, Repository>, versions: [Version]) -> Int {
        guard
            let defaultVersion = versions.latest(for: .defaultBranch),
            let repo = package.repository
        else { return 0 }

        let hasDocumentation: Bool = {
            if let spiManifest = defaultVersion.spiManifest,
               let _ = spiManifest.externalLinks?.documentation {
                return true
            } else {
                return [
                    defaultVersion,
                    versions.latest(for: .release),
                    versions.latest(for: .preRelease)
                ].compactMap { $0 }.documentationTarget() != nil
            }
        }()

        return Score.compute(
            .init(licenseKind: repo.license.licenseKind,
                  releaseCount: versions.releases.count,
                  likeCount: repo.stars,
                  isArchived: repo.isArchived,
                  numberOfDependencies: defaultVersion.resolvedDependencies?.count,
                  lastActivityAt: repo.lastActivityAt,
                  hasDocumentation: hasDocumentation)
        )
    }
}


private extension Array where Element == Version {
    func latest(for kind: Version.Kind) -> Version? {
        first { $0.latest == kind }
    }

    var releases: Self { filter { $0.reference.isTag } }
}

