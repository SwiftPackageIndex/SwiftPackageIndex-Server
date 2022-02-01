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
        var reference: Reference?
        var platform: Build.Platform
        var swiftVersion: SwiftVersion
        var status: Build.Status
        var runnerId: String?

        internal init(buildId: UUID,
                      createdAt: Date,
                      packageName: String?,
                      repositoryOwner: String,
                      repositoryName: String,
                      reference: Reference?,
                      platform: Build.Platform,
                      swiftVersion: SwiftVersion,
                      status: Build.Status,
                      runnerId: String?) {
            self.buildId = buildId
            self.createdAt = createdAt
            self.packageName = packageName ?? repositoryName
            self.repositoryOwner = repositoryOwner
            self.repositoryName = repositoryName
            self.reference = reference
            self.platform = platform
            self.swiftVersion = swiftVersion
            self.status = status
            self.runnerId = runnerId
        }

        init?(buildResult: BuildResult) {
            guard let id = buildResult.build.id,
                  let createdAt = buildResult.build.createdAt,
                  let owner = buildResult.repository.owner,
                  let name = buildResult.repository.name
            else { return nil }

            self.init(buildId: id, createdAt: createdAt, packageName: buildResult.version.packageName, repositoryOwner: owner, repositoryName: name, reference: buildResult.version.reference, platform: buildResult.build.platform, swiftVersion: buildResult.build.swiftVersion, status: buildResult.build.status, runnerId: buildResult.build.runnerId)
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
                        .unwrap(reference, { $0.node })
                    ),
                    .div(
                        .text("Swift "),
                        .text("\(swiftVersion)"),
                        .text(" on "),
                        .text("\(platform)")
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
    }
}

private extension Reference {

    var node: Node<HTML.BodyContext> {
        switch self {
            case let .branch(branchName):
                return .span(
                    .class("branch"),
                    .text(branchName)
                )
            case let .tag(_, taggedVersion):
                return .span(
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
