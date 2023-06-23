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


extension API.PackageController.GetRoute.Model {
    static var mock: Self {
        .init(
            packageId: UUID("cafecafe-cafe-cafe-cafe-cafecafecafe")!,
            repositoryOwner: "Alamo",
            repositoryOwnerName: "Alamofire",
            repositoryName: "Alamofire",
            activity: .init(
                openIssuesCount: 27,
                openIssuesURL: "https://github.com/Alamofire/Alamofire/issues",
                openPullRequestsCount: 5,
                openPullRequestsURL: "https://github.com/Alamofire/Alamofire/pulls",
                lastIssueClosedAt: Current.date().adding(days: -5),
                lastPullRequestClosedAt: Current.date().adding(days: -6)
            ),
            authors: AuthorMetadata.fromGitRepository(.init(authors: [
                .init(name: "Author One"),
                .init(name: "Author Two"),
                .init(name: "Author Three"),
            ], numberOfContributors: 5)),
            swiftVersionBuildInfo: .init(
                stable: NamedBuildResults(
                    referenceName: "5.2.3",
                    results: .init(status5_6: .incompatible,
                                   status5_7: .incompatible,
                                   status5_8: .unknown,
                                   status5_9: .compatible)),
                beta: NamedBuildResults(
                    referenceName: "6.0.0-b1",
                    results: .init(status5_6: .incompatible,
                                   status5_7: .compatible,
                                   status5_8: .compatible,
                                   status5_9: .compatible)),
                latest: NamedBuildResults(
                    referenceName: "main",
                    results: .init(status5_6: .incompatible,
                                   status5_7: .incompatible,
                                   status5_8: .unknown,
                                   status5_9: .compatible))),
            platformBuildInfo: .init(
                stable: NamedBuildResults(
                    referenceName: "5.2.3",
                    results: .init(iOSStatus: .compatible,
                                   linuxStatus: .unknown,
                                   macOSStatus: .unknown,
                                   tvOSStatus: .unknown,
                                   watchOSStatus: .unknown)),
                beta: NamedBuildResults(
                    referenceName: "6.0.0-b1",
                    results: .init(iOSStatus: .compatible,
                                   linuxStatus: .compatible,
                                   macOSStatus: .compatible,
                                   tvOSStatus: .compatible,
                                   watchOSStatus: .unknown)),
                latest: NamedBuildResults(
                    referenceName: "main",
                    results: .init(iOSStatus: .compatible,
                                   linuxStatus: .compatible,
                                   macOSStatus: .compatible,
                                   tvOSStatus: .compatible,
                                   watchOSStatus: .compatible))),
            history: .init(
                createdAt: Calendar.current.date(byAdding: .day,
                                                 value: -70,
                                                 to: Current.date())!,
                commitCount: 1433,
                commitCountURL: "https://github.com/Alamofire/Alamofire/commits/main",
                releaseCount: 79,
                releaseCountURL: "https://github.com/Alamofire/Alamofire/releases"
            ),
            license: .mit,
            licenseUrl: nil,
            productCounts: .init(libraries: 3, executables: 1, plugins: 0),
            releases: .init(stable: .init(date: Current.date().adding(days: -12),
                                          link: .init(label: "5.2.0",
                                                      url: "https://github.com/Alamofire/Alamofire/releases/tag/5.2.0")),
                            beta: .init(date: Current.date().adding(days: -4),
                                        link: .init(label: "5.3.0-beta.1",
                                                    url: "https://github.com/Alamofire/Alamofire/releases/tag/5.3.0-beta.1")),
                            latest: .init(date: Current.date().adding(minutes: -12),
                                          link: .init(label: "main",
                                                      url: "https://github.com/Alamofire/Alamofire"))),
            dependencies: [
                .init(packageName: "Alamofire", repositoryURL: "https://github.com/Alamofire/Alamofire.git"),
                .init(packageName: "AlamofireImage", repositoryURL: "https://github.com/Alamofire/AlamofireImage.git")
            ],
            stars: 17,
            summary: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque quis porttitor erat. Vivamus porttitor mi odio, quis imperdiet velit blandit id. Vivamus vehicula urna eget ipsum laoreet, sed porttitor sapien malesuada. Mauris faucibus tellus at augue vehicula, vitae aliquet felis ullamcorper. Praesent vitae leo rhoncus, egestas elit id, porttitor lacus. Cras ac bibendum mauris. Praesent luctus quis nulla sit amet tempus. Ut pharetra non augue sed pellentesque.",
            title: "Alamofire",
            url: "https://github.com/Alamofire/Alamofire.git",
            score: 10,
            isArchived: false,
            defaultBranchReference: .branch("main"),
            releaseReference: .tag(5, 2, 0),
            preReleaseReference: .tag(5, 3, 0, "beta.1")
        )
    }
}
