@testable import App

import XCTVapor


class RecentViewsTests: AppTestCase {

    func test_recentPackages() throws {
        // setup
        do {  // 1st package is eligible
            let pkg = Package(id: UUID(), url: "1")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           summary: "pkg 1",
                           name: "1",
                           owner: "foo").create(on: app.db).wait()
            try Version(package: pkg, packageName: "1").save(on: app.db).wait()
        }
        do {  // 2nd package should not be selected, because it has no package name
            let pkg = Package(id: UUID(), url: "2")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           summary: "pkg 2",
                           name: "2",
                           owner: "foo").create(on: app.db).wait()
            try Version(package: pkg).save(on: app.db).wait()
        }
        do {  // 3rd package is eligible
            let pkg = Package(id: UUID(), url: "3")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           summary: "pkg 3",
                           name: "3",
                           owner: "foo").create(on: app.db).wait()
            try Version(package: pkg, packageName: "3").save(on: app.db).wait()
        }
        // make sure to refresh the materialized view
        try RecentPackage.refresh(on: app.db).wait()

        // MUT
        let res = try RecentPackage.fetch(on: app.db).wait()

        // validate
        XCTAssertEqual(res.map(\.packageName), ["3", "1"])
        XCTAssertEqual(res.map(\.packageSummary), ["pkg 3", "pkg 1"])
    }

    func test_recentReleases() throws {
        // setup
        do {  // 1st package is eligible
            let pkg = Package(id: UUID(), url: "1")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           summary: "pkg 1",
                           defaultBranch: "default",
                           name: "1",
                           owner: "foo").create(on: app.db).wait()
            try Version(package: pkg,
                        reference: .tag(.init(1, 2, 3)),
                        packageName: "1",
                        commitDate: Date(timeIntervalSince1970: 0)).save(on: app.db).wait()
        }
        do {  // 2nd package is ineligible, because it has a branch reference
            let pkg = Package(id: UUID(), url: "2")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           summary: "pkg 2",
                           defaultBranch: "default",
                           name: "2",
                           owner: "foo").create(on: app.db).wait()
            try Version(package: pkg,
                        reference: .branch("default"),
                        packageName: "2",
                        commitDate: Date(timeIntervalSince1970: 0)).save(on: app.db).wait()
        }
        do {  // 3rd package is ineligible, because it has no package name
            let pkg = Package(id: UUID(), url: "3")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           summary: "pkg 3",
                           defaultBranch: "default",
                           name: "3",
                           owner: "foo").create(on: app.db).wait()
            try Version(package: pkg,
                        reference: .branch("default"),
                        commitDate: Date(timeIntervalSince1970: 0)).save(on: app.db).wait()
        }
        do {  // 4th package is ineligible, because it has no reference
            let pkg = Package(id: UUID(), url: "4")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           summary: "pkg 4",
                           defaultBranch: "default",
                           name: "4",
                           owner: "foo").create(on: app.db).wait()
            try Version(package: pkg,
                        packageName: "4",
                        commitDate: Date(timeIntervalSince1970: 0)).save(on: app.db).wait()
        }
        do {  // 5th package is eligible - should come before 1st because of more recent commit date
            let pkg = Package(id: UUID(), url: "5")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg,
                           summary: "pkg 5",
                           defaultBranch: "default",
                           name: "5",
                           owner: "foo").create(on: app.db).wait()
            try Version(package: pkg,
                        reference: .tag(.init(2, 0, 0)),
                        packageName: "5",
                        commitDate: Date(timeIntervalSince1970: 1)).save(on: app.db).wait()
        }

        // make sure to refresh the materialized view
        try RecentRelease.refresh(on: app.db).wait()

        // MUT
        let res = try RecentRelease.fetch(on: app.db).wait()

        // validate
        XCTAssertEqual(res.map(\.packageName), ["5", "1"])
        XCTAssertEqual(res.map(\.version), ["2.0.0", "1.2.3"])
        XCTAssertEqual(res.map(\.packageSummary), ["pkg 5", "pkg 1"])
    }

    func test_recentReleases_Filter() throws {
        XCTAssertTrue(RecentRelease.Filter.minor == .init("minor"))
        XCTAssertTrue(RecentRelease.Filter.major == .init("major"))
        XCTAssertTrue(RecentRelease.Filter.patch == .init("patch"))
        XCTAssertTrue(RecentRelease.Filter.all == [.init("minor"), .init("major"), .init("patch")])
        XCTAssertTrue(RecentRelease.Filter.all == .init("nonsensical defaults to all"))
    }

    func test_recentReleases_filter() throws {
        // List only major releases
        // setup
        let releases: [RecentRelease] = (1...12).map {
            let major = $0 / 3  // 0, 0, 1, 1, 1, 2, 2, 2, 3, 3
            let minor = $0 % 3  // 1, 2, 0, 1, 2, 0, 1, 2, 0, 1
            let patch = $0 % 2  // 1, 0, 1, 0, 1, 0, 1, 0, 1, 0
            let pre = $0 <= 10 ? "" : "-b1"
            return RecentRelease(id: UUID(),
                                 repositoryOwner: "",
                                 repositoryName: "",
                                 packageName: "",
                                 packageSummary: nil,
                                 version: "\(major).\(minor).\(patch)\(pre)",
                                 releasedAt: Date())
        }

        // MUT
        let all = RecentRelease.filterReleases(releases, by: .all)
        let majorOnly = RecentRelease.filterReleases(releases, by: .major)
        let minorOnly = RecentRelease.filterReleases(releases, by: .minor)
        let majorMinor = RecentRelease.filterReleases(releases, by: [.major, .minor])
        let pre = RecentRelease.filterReleases(releases, by: [.pre])

        // validate
        XCTAssertEqual(
            all.map(\.version),
            ["0.1.1", "0.2.0", "1.0.1", "1.1.0", "1.2.1", "2.0.0", "2.1.1", "2.2.0", "3.0.1", "3.1.0",
             "3.2.1-b1", "4.0.0-b1"])
        XCTAssertEqual(
            majorOnly.map(\.version), ["2.0.0"])
        XCTAssertEqual(
            minorOnly.map(\.version), ["0.2.0", "1.1.0", "2.2.0", "3.1.0"])
        XCTAssertEqual(
            majorMinor.map(\.version), ["0.2.0", "1.1.0", "2.0.0", "2.2.0", "3.1.0"])
        XCTAssertEqual(
            pre.map(\.version), ["3.2.1-b1", "4.0.0-b1"])
    }

    func test_recentPackages_dedupe_issue() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/315
        // setup
        // Package with two eligible versions that differ in package name
        let pkg = Package(id: UUID(), url: "1")
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       summary: "pkg summary",
                       name: "bar",
                       owner: "foo").create(on: app.db).wait()
        try Version(package: pkg,
                    packageName: "pkg-bar",
                    commitDate: Date(timeIntervalSince1970: 0)).save(on: app.db).wait()
        try Version(package: pkg,
                    packageName: "pkg-bar-updated",
                    commitDate: Date(timeIntervalSince1970: 1)).save(on: app.db).wait()
        // make sure to refresh the materialized view
        try RecentPackage.refresh(on: app.db).wait()

        // MUT
        let res = try RecentPackage.fetch(on: app.db).wait()

        // validate
        XCTAssertEqual(res.map(\.packageName), ["pkg-bar-updated"])
    }

    func test_recentReleases_dedupe_issue() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/315
        // setup
        let pkg = Package(id: UUID(), url: "1")
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       summary: "pkg summary",
                       name: "bar",
                       owner: "foo").create(on: app.db).wait()
        try Version(package: pkg,
                    reference: .tag(.init(1, 0, 0)),
                    packageName: "pkg-bar",
                    commitDate: Date(timeIntervalSince1970: 0)).save(on: app.db).wait()
        try Version(package: pkg,
                    reference: .tag(.init(1, 0, 1)),
                    packageName: "pkg-bar-updated",
                    commitDate: Date(timeIntervalSince1970: 1)).save(on: app.db).wait()
        // make sure to refresh the materialized view
        try RecentRelease.refresh(on: app.db).wait()

        // MUT
        let res = try RecentRelease.fetch(on: app.db).wait()

        // validate
        XCTAssertEqual(res.map(\.packageName), ["pkg-bar-updated"])
    }

}
