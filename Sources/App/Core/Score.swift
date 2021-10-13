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

enum Score {
    struct Input {
        var supportsLatestSwiftVersion: Bool
        var licenseKind: License.Kind
        var releaseCount: Int
        var likeCount: Int
        var isArchived: Bool
    }
    
    static func compute(_ candidate: Input) -> Int {
        var score = 0
        
        // Swift major version support
        if candidate.supportsLatestSwiftVersion { score += 10 }
		
        // Is the package archived and no longer receiving updates?
        if candidate.isArchived { score -= 10 }
        
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
        
        return score
    }

    static func compute(package: Joined<Package, Repository>, versions: [Version]) -> Int {
        guard
            let defaultVersion = versions.latest(for: .defaultBranch),
            let repo = package.repository,
            let starsCount = repo.stars
        else { return 0 }
        return Score.compute(
            .init(supportsLatestSwiftVersion: defaultVersion.supportsMajorSwiftVersion(SwiftVersion.latestMajor),
                  licenseKind: repo.license.licenseKind,
                  releaseCount: versions.releases.count,
                  likeCount: starsCount,
                  isArchived: repo.isArchived ?? false)
        )
    }
}
