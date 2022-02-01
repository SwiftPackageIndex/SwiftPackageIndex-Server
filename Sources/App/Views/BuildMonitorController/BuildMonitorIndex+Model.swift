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
        var repositoryOwnerName: String?
        var reference: Reference?
        var platform: Build.Platform
        var swiftVersion: SwiftVersion
        var status: Build.Status
        var runnerId: String?

        internal init(buildId: UUID,
                      createdAt: Date,
                      packageName: String,
                      repositoryOwnerName: String?,
                      platform: Build.Platform,
                      swiftVersion: SwiftVersion,
                      reference: Reference?,
                      status: Build.Status,
                      runnerId: String?) {
            self.buildId = buildId
            self.createdAt = createdAt
            self.packageName = packageName
            self.repositoryOwnerName = repositoryOwnerName
            self.platform = platform
            self.swiftVersion = swiftVersion
            self.reference = reference
            self.status = status
            self.runnerId = runnerId
        }

        init?(buildResult: BuildResult) {
            guard let id = buildResult.build.id,
                  let createdAt = buildResult.build.createdAt
            else { return nil }

            self.init(buildId: id,
                      createdAt: createdAt,
                      packageName: buildResult.version.packageName ?? buildResult.repository.name ?? "Unknown Package",
                      repositoryOwnerName: buildResult.repository.ownerName ?? buildResult.repository.ownerName,
                      platform: buildResult.build.platform,
                      swiftVersion: buildResult.build.swiftVersion,
                      reference: buildResult.version.reference,
                      status: buildResult.build.status,
                      runnerId: buildResult.build.runnerId)
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
                        .h3(
                            .text(packageName),
                            .unwrap(repositoryOwnerName, { .span(" by \($0)") })
                        )
                    ),
                    .div(
                        .class("status \(status.cssClass)"),
                        .span(.text(status.description))
                    ),
                    .div(
                        .unwrap(reference, { $0.node })
                    ),
                    .div(
                        .text("Swift \(swiftVersion)")
                    ),
                    .div(
                        .text(platform.displayName)
                    ),
                    .div(
                        .text(runner)
                    ),
                    .div(
                        .text("\(date: createdAt, relativeTo: Current.date())")
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
