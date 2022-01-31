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
import Plot

extension BuildMonitorIndex {

    struct Model {
        var buildId: UUID
        var createdAt: Date
        var packageName: String
        var repositoryOwner: String
        var repositoryName: String
        var branchName: String?
        var taggedVersion: String?
        var platform: String
        var swiftVersion: String
        var status: Build.Status
        var runnerId: String?

        internal init(buildId: UUID,
                      createdAt: Date,
                      packageName: String = "LeftPad LongPackage",
                      repositoryOwner: String = "daveverwer",
                      repositoryName: String = "LeftPad",
                      branchName: String? = "main",
                      taggedVersion: String? = nil,
                      platform: String = "Linux",
                      swiftVersion: String = "5.5",
                      status: Build.Status,
                      runnerId: String?) {
            self.buildId = buildId
            self.createdAt = createdAt
            self.packageName = packageName
            self.repositoryOwner = repositoryOwner
            self.repositoryName = repositoryName
            self.branchName = branchName
            self.taggedVersion = taggedVersion
            self.platform = platform
            self.swiftVersion = swiftVersion
            self.status = status
            self.runnerId = runnerId
        }

        init(build: Build) {
//            guard let id = build.id,
//                  let createdAt = build.createdAt
//            else { return nil }

            let id = try! build.requireID()
            self.init(buildId: id, createdAt: build.createdAt ?? Date(), status: build.status, runnerId: build.runnerId)
        }

        var runner: String {
            guard let runnerId = runnerId,
                  let runner = BuildRunner(rawValue: runnerId)
            else { return "" }
            return runner.description
        }

        func buildMonitorItem() -> Node<HTML.BodyContext> {
            .a(
                .href(SiteURL.builds(.value(buildId)).relativeURL()),
                .div(
                    .class("row"),
                    .div(
                        .class("package_name"),
                        .h3(.text(packageName))
                    ),
                    .div(
                        .class("status \(status.cssClass)"),
                        .span(.text(status.description))
                    ),
                    .div(
                        .unwrap(branchName, { branchNameNode(branchName: $0) }),
                        .unwrap(taggedVersion, { taggedVersionNode(taggedVersion: $0) })
                    ),
                    .div(
                        .text("Swift "),
                        .text(swiftVersion),
                        .text(" on "),
                        .text(platform)
                    ),
                    .div(
                        .text("\(date: createdAt, relativeTo: Current.date())")
                    ),
                    .div(
                        .text(runner)
                    )
                )
            )
        }

        func branchNameNode(branchName: String) -> Node<HTML.BodyContext> {
            .span(
                .class("branch"),
                .text(branchName)
            )
        }

        func taggedVersionNode(taggedVersion: String) -> Node<HTML.BodyContext> {
            .span(
                .class("version"),
                .text(taggedVersion)
            )
        }
    }
}

private extension Build.Status {
    var cssClass: String {
        switch self {
            case .ok: return "ok"
            case .failed: return "failed"
            case .infrastructureError, .triggered, .timeout: return "other"
        }
    }
}
