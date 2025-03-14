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

@testable import App

import Plot
import Testing


extension AllTests.BuildIndexModelTests {

    @Test func init_no_name() async throws {
        // Tests behaviour when we're lacking data
        try await withApp { app in
            // setup package without package name
            let pkg = try await savePackage(on: app.db, "1".url)
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 forks: 42,
                                 license: .mit,
                                 name: "bar",
                                 owner: "foo",
                                 stars: 17,
                                 summary: "summary").save(on: app.db)
            try await Version(package: pkg, latest: .defaultBranch).save(on: app.db)
            let (pkgInfo, buildInfo) = try await PackageController.BuildsRoute
                .query(on: app.db, owner: "foo", repository: "bar")

            // MUT
            let m = BuildIndex.Model(packageInfo: pkgInfo, buildInfo: buildInfo)

            // validate
            #expect(m != nil)
        }
    }

    @Test func completedBuildCount() throws {
        let m = BuildIndex.Model.mock
        // mock contains build for three Swift versions, 5.3, 5.4, 5.5
        // each has the same default setup:
        // - 4 x .ok
        // - 1 x .failed
        // - 1 x .triggered
        // -> 5 completed per Swift version (4 x .ok + .failed)
        // -> 15 completed per package version
        //    (there are 3 versions, default branch, release, and beta)
        // -> 45 completed overall
        // -> 44 minus the linux/5.5 build to test .none
        // -> 44 the tvos/5.5 build to test .timeout does not change the completed tally
        // -> 43 minus the watchos/5.5 build to test .infrastructureError
        // -> 43 completed in total
        #expect(m.completedBuildCount == 43)
    }

    @Test func packageURL() throws {
        let m = BuildIndex.Model.mock
        #expect(m.packageURL == "/foo/foobar")
    }

    @Test func buildMatrix() throws {
        // setup
        let id = UUID()
        let stable: [BuildInfo] = [
            .init(id: id, swiftVersion: .v3, platform: .iOS, status: .ok, docStatus: .ok),
            .init(id: id, swiftVersion: .v2, platform: .macosXcodebuild, status: .ok, docStatus: nil),
            .init(id: id, swiftVersion: .v1, platform: .tvOS, status: .ok, docStatus: nil),
        ]
        let latest: [BuildInfo] = [
            .init(id: id, swiftVersion: .v2, platform: .macosSpm, status: .failed, docStatus: nil),
            .init(id: id, swiftVersion: .v1, platform: .tvOS, status: .ok, docStatus: nil),
        ]
        let model = BuildIndex.Model.init(owner: "foo",
                                          ownerName: "Foo",
                                          repositoryName: "bar",
                                          packageName: "bar",
                                          buildGroups: [
                                            .init(name: "1.2.3", kind: .release, builds: stable),
                                            .init(name: "2.0.0-b1", kind: .preRelease, builds: []),
                                            .init(name: "main", kind: .defaultBranch, builds: latest),
                                          ])

        // MUT
        let matrix = model.buildMatrix

        // validate
        #expect(matrix.values.keys.count == 27)
        #expect(
            matrix.values[.init(swiftVersion: .v3, platform: .iOS)]?.map(\.column.label) == ["1.2.3", "2.0.0-b1", "main"]
        )
        #expect(
            matrix.values[.init(swiftVersion: .v3, platform: .iOS)]?.map(\.value?.status) == .some([.ok, nil, nil])
        )
        #expect(
            matrix.values[.init(swiftVersion: .v2,
                                platform: .macosXcodebuild)]?.map(\.value?.status) == [.ok, nil, nil]
        )
        #expect(
            matrix.values[.init(swiftVersion: .v2, platform: .macosSpm)]?.map(\.value?.status) == [nil, nil, .failed]
        )
        #expect(
            matrix.values[.init(swiftVersion: .v1, platform: .tvOS)]?.map(\.value?.status) == [.ok, nil, .ok]
        )
    }

    @Test func buildMatrix_no_beta() throws {
        // Test BuildMatrix mapping, in particular absence of a beta version
        // setup
        let id = UUID()
        let stable: [BuildInfo] = [
            .init(id: id, swiftVersion: .v3, platform: .iOS, status: .ok, docStatus: nil),
            .init(id: id, swiftVersion: .v2, platform: .macosXcodebuild, status: .ok, docStatus: nil),
            .init(id: id, swiftVersion: .v1, platform: .tvOS, status: .ok, docStatus: nil),
        ]
        let latest: [BuildInfo] = [
            .init(id: id, swiftVersion: .v2, platform: .macosSpm, status: .failed, docStatus: nil),
            .init(id: id, swiftVersion: .v1, platform: .tvOS, status: .ok, docStatus: nil),
        ]
        let model = BuildIndex.Model.init(owner: "foo",
                                          ownerName: "Foo",
                                          repositoryName: "bar",
                                          packageName: "bar",
                                          buildGroups: [
                                            .init(name: "1.2.3", kind: .release, builds: stable),
                                            .init(name: "main", kind: .defaultBranch, builds: latest),
                                          ])

        // MUT
        let matrix = model.buildMatrix

        // validate
        #expect(matrix.values.keys.count == 27)
        #expect(
            matrix.values[.init(swiftVersion: .v3, platform: .iOS)]?.map(\.column.label) == ["1.2.3", "main"]
        )
        #expect(
            matrix.values[.init(swiftVersion: .v3, platform: .iOS)]?.map(\.value?.status) == [.ok, nil]
        )
        #expect(
            matrix.values[.init(swiftVersion: .v2,
                                platform: .macosXcodebuild)]?.map(\.value?.status) == [.ok, nil]
        )
        #expect(
            matrix.values[.init(swiftVersion: .v2,
                                platform: .macosSpm)]?.map(\.value?.status) == [nil, .failed]
        )
        #expect(
            matrix.values[.init(swiftVersion: .v1, platform: .tvOS)]?.map(\.value?.status) == [.ok, .ok]
        )
    }

    @Test func render_BuildCell() throws {
        let id = UUID()
        #expect(BuildCell("1.2.3", .release, id, .ok, docStatus: nil).node.render() == """
            <div class="succeeded"><a href="/builds/\(id.uuidString)">Succeeded</a></div>
            """)
        #expect(BuildCell("1.2.3", .release, id, .ok, docStatus: .ok).node.render() == """
            <div class="succeeded"><a href="/builds/\(id.uuidString)">Succeeded</a><span class="generated-docs" title="If successful, this build generated package documentation."></span></div>
            """)
        #expect(BuildCell("1.2.3", .release, id, .failed, docStatus: nil).node.render() == """
            <div class="failed"><a href="/builds/\(id.uuidString)">Failed</a></div>
            """)
        #expect(BuildCell("1.2.3", .release).node.render() == """
            <div><span>Pending</span></div>
            """)
    }

    @Test func render_BuildItem() throws {
        // setup
        let id = UUID()
        let bi = BuildItem(index: .init(swiftVersion: .v3, platform: .iOS),
                           values: [.init("1.2.3", .release, id, .ok, docStatus: nil),
                                    .init("2.0.0-b1", .preRelease),
                                    .init("develop", .defaultBranch, id, .failed, docStatus: nil)])

        // MUT - altogether now
        let node = bi.node

        let expectation: Node<HTML.ListContext> = .li(
            .class("row"),
            .div(
                .class("row-labels"),
                .strong("iOS")
            ),
            .div(
                .class("column-labels"),
                .div(.span(.class("stable"), .text("1.2.3"))),
                .div(.span(.class("beta"), .text("2.0.0-b1"))),
                .div(.span(.class("branch"), .text("develop")))
            ),
            .div(
                .class("results"),
                .div(.class("succeeded"), .a(.href("/builds/\(id.uuidString)"), .text("Succeeded"))),
                .div(.span(.text("Pending"))),
                .div(.class("failed"), .a(.href("/builds/\(id.uuidString)"), .text("Failed")))
            )
        )
        #expect(node.render() == expectation.render())
   }

    @Test func BuildItem_generatedDocs() throws {
        // setup
        let id = UUID()
        let bi = BuildItem(index: .init(swiftVersion: .v3, platform: .iOS),
                           values: [ .init("main", .defaultBranch, id, .ok, docStatus: .ok) ])

        // MUT
        let node = bi.node

        let expectation: Node<HTML.ListContext> = .li(
            .class("row"),
            .div(
                .class("row-labels"),
                .strong("iOS")
            ),
            .div(
                .class("column-labels"),
                .div(.span(.class("branch"), .text("main")))
            ),
            .div(
                .class("results"),
                .div(
                    .class("succeeded"),
                    .a(
                        .href("/builds/\(id.uuidString)"),
                        .text("Succeeded")
                    ),
                    .span(
                        .class("generated-docs"),
                        .title("If successful, this build generated package documentation.")
                    )
                )
            )
        )
        #expect(node.render() == expectation.render())
    }
}


fileprivate typealias BuildCell = BuildIndex.Model.BuildCell
fileprivate typealias BuildInfo = BuildIndex.Model.BuildInfo
fileprivate typealias BuildItem = BuildIndex.Model.BuildItem
