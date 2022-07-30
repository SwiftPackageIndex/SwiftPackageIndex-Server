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

import Plot


extension BuildIndex {
    struct Model {
        var owner: String
        var ownerName: String
        var repositoryName: String
        var packageName: String
        var completedBuildCount: Int
        var buildMatrix: BuildMatrix

        internal init(owner: String,
                      ownerName: String,
                      repositoryName: String,
                      packageName: String,
                      buildGroups: [BuildGroup]) {
            self.owner = owner
            self.ownerName = ownerName
            self.repositoryName = repositoryName
            self.packageName = packageName
            self.completedBuildCount = buildGroups.reduce(0) { $0 + $1.builds.filter(\.isCompleted).count }
            buildMatrix = .init(buildGroups: buildGroups)
        }

        init?(packageInfo: PackageController.BuildsRoute.PackageInfo, buildInfo: [PackageController.BuildsRoute.BuildInfo]) {
            let buildGroups = [Version.Kind.release, .preRelease, .defaultBranch]
                .compactMap(buildInfo.grouped(by:))

            self.init(owner: packageInfo.repositoryOwner,
                      ownerName: packageInfo.repositoryOwnerName ?? packageInfo.repositoryOwner,
                      repositoryName: packageInfo.repositoryName,
                      packageName: packageInfo.packageName ?? packageInfo.repositoryName,
                      buildGroups: buildGroups)
        }
    }
}


private extension Array where Element == PackageController.BuildsRoute.BuildInfo {
    func grouped(by kind: Version.Kind) -> BuildIndex.Model.BuildGroup? {
        let filteredBuildInfo = filter { $0.versionKind == kind }
        guard let name = filteredBuildInfo.first?.reference.description else { return nil }
        let buildInfo = filteredBuildInfo.map {
            BuildIndex.Model.BuildInfo.init(id: $0.buildId,
                                            swiftVersion: $0.swiftVersion,
                                            platform: $0.platform,
                                            status: $0.status)
        }
        return .init(name: name, kind: kind, builds: buildInfo)
    }
}


extension BuildIndex.Model {
    struct BuildGroup {
        var name: String
        var kind: App.Version.Kind
        var builds: [BuildInfo]

        internal init(name: String, kind: App.Version.Kind, builds: [BuildInfo]) {
            self.name = name
            self.kind = kind
            self.builds = builds
        }
    }
}


extension BuildIndex.Model {
    struct BuildInfo {
        var id: App.Build.Id
        var platform: App.Build.Platform
        var status: App.Build.Status
        var swiftVersion: App.SwiftVersion

        var isCompleted: Bool { status.isCompleted }

        init?(_ build: App.Build) {
            guard let id = build.id else { return nil }
            self.init(id: id,
                      swiftVersion: build.swiftVersion,
                      platform: build.platform,
                      status: build.status)
        }

        internal init(id: App.Build.Id,
                      swiftVersion: App.SwiftVersion,
                      platform: App.Build.Platform,
                      status: App.Build.Status) {
            self.id = id
            self.platform = platform
            self.status = status
            self.swiftVersion = swiftVersion
        }
    }
}


extension BuildIndex.Model {
    var packageURL: String {
        SiteURL.package(.value(owner), .value(repositoryName), .none).relativeURL()
    }

    struct BuildMatrix {
        var values: [RowIndex: [BuildCell]]

        init(buildGroups: [BuildGroup]) {
            values = Dictionary.init(uniqueKeysWithValues: RowIndex.all.map { ($0, []) })

            for group in buildGroups {
                var column = [RowIndex: BuildCell]()
                for build in group.builds {
                    guard let index = RowIndex(build) else { continue }
                    column[index] = .init(group.name, group.kind, build.id, build.status)
                }
                RowIndex.all.forEach {
                    values[$0, default: []]
                        .append(column[$0, default: BuildCell(group.name, group.kind)])
                }
            }
        }

        subscript(swiftVersion: SwiftVersion) -> [BuildItem] {
            RowIndex.all.filter { $0.swiftVersion.isCompatible(with: swiftVersion) }
                .sorted(by: { $0.platform < $1.platform })
                .map { BuildItem(index: $0, values: values[$0] ?? []) }
        }
    }

    struct BuildCell: Equatable {
        var column: ColumnIndex
        var value: Value?

        init(_ column: String, _ kind: App.Version.Kind, _ id: App.Build.Id, _ status: Build.Status) {
            self.column = .init(label: column, kind: kind)
            self.value = .init(id: id, status: status)
        }

        init(_ column: String, _ kind: App.Version.Kind) {
            self.column = .init(label: column, kind: kind)
        }

        var node: Node<HTML.BodyContext> {
            guard let value = value else {
                // No value indicates a missing/pending build
                return cell(text: "Build Pending")
            }

            let buildURL = SiteURL.builds(.value(value.id)).relativeURL()

            switch value.status {
                case .ok: return cell(text: "Build Succeeded", linkURL: buildURL, cssClass: "succeeded")
                case .failed: return cell(text: "Build Failed", linkURL: buildURL, cssClass: "failed")
                case .triggered: return cell(text: "Build Queued")
                case .infrastructureError: return cell(text: "Build Errored")
                case .timeout: return cell(text: "Build Timed Out")
            }
        }

        func cell(text: String) -> Node<HTML.BodyContext> {
            return .div(
                .span(
                    .text(text)
                )
            )
        }

        func cell(text: String, linkURL: String, cssClass: String) -> Node<HTML.BodyContext> {
            return .div(
                .class(cssClass),
                .a(
                    .href(linkURL),
                    .text(text)
                )
            )
        }

        struct Value: Equatable {
            var id: App.Build.Id
            var status: App.Build.Status
        }
    }

    struct ColumnIndex: Equatable {
        var label: String
        var kind: App.Version.Kind

        var node: Node<HTML.BodyContext> {
            return .div(
                .span(
                    .class(kind.cssClass),
                    .text(label)
                )
            )
        }
    }

    struct RowIndex: Hashable {
        var swiftVersion: SwiftVersion
        var platform: Build.Platform

        init?(_ build: BuildInfo) {
            guard let swiftVersion = build.swiftVersion.compatibility else { return nil }
            self.init(swiftVersion: swiftVersion, platform: build.platform)
        }

        internal init(swiftVersion: SwiftVersion, platform: Build.Platform) {
            self.swiftVersion = swiftVersion
            self.platform = platform
        }

        static var all: [RowIndex] {
            BuildPair.all
                .sorted {
                    $0.swiftVersion != $1.swiftVersion
                        ? $0.swiftVersion > $1.swiftVersion
                        : $0.platform < $0.platform
                }
                .map { RowIndex(swiftVersion: $0.swiftVersion, platform: $0.platform) }
        }
    }

    struct BuildItem {
        var index: RowIndex
        var values: [BuildCell]

        var node: Node<HTML.ListContext> {
            .li(
                .class("row"),
                .div(
                    .class("row-labels"),
                    .strong(.text(index.platform.displayName))
                ),
                .div(
                    .class("column-labels"),
                    .group(values.map(\.column.node))
                ),
                .div(
                    .class("results"),
                    .group(values.map(\.node))
                )
            )
        }
    }

}
