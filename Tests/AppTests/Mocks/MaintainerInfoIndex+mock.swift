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

import Foundation

extension MaintainerInfoIndex.Model {
    static var mock: MaintainerInfoIndex.Model {
        .init(packageName: "Example Package",
              repositoryOwner: "example",
              repositoryOwnerName: "Example Owner",
              repositoryName: "package",
              score: 10,
              scoreDetails: Score.ScoreDetails(
                candidate: Score.Input(
                    licenseKind: .compatibleWithAppStore,
                    releaseCount: 10,
                    likeCount: 30,
                    isArchived: false,
                    hasDocumentation: true,
                    hasReadme: true,
                    numberOfContributors: 20,
                    hasTestTargets: false
                ),
                scoreBreakdown: [
                    .archive: 20,
                    .license: 20,
                    .releases: 20,
                    .stars: 20,
                    .dependencies: 20,
                    .maintenance: 20,
                    .documentation: 20,
                    .readme: 20,
                    .contributors: 20,
                    .tests: 20
                ]
              )
        )
    }
}
