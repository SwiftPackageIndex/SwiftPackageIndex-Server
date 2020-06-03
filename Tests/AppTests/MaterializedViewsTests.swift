@testable import App

import XCTVapor


class MaterializedViewsTests: AppTestCase {

    func test_recentPackages() throws {
        // setup
        do {  // 1st package is eligible
            let pkg = Package(id: UUID(), url: "1")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg, name: "1", owner: "foo").create(on: app.db).wait()
            try Version(package: pkg, packageName: "1").save(on: app.db).wait()
        }
        do {  // 2nd package should not be selected, because it has no package name
            let pkg = Package(id: UUID(), url: "2")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg, name: "2", owner: "foo").create(on: app.db).wait()
            try Version(package: pkg).save(on: app.db).wait()
        }
        do {  // 3rd package is eligible
            let pkg = Package(id: UUID(), url: "3")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg, name: "3", owner: "foo").create(on: app.db).wait()
            try Version(package: pkg, packageName: "3").save(on: app.db).wait()
        }
        // make sure to refresh the materialized view
        try RecentPackage.refresh(on: app.db).wait()

        // MUT
        let res = try RecentPackage.fetch(on: app.db).wait()

        // validate
        XCTAssertEqual(res.map(\.packageName), ["3", "1"])
    }

    func test_recentReleases() throws {
        // setup
        do {  // 1st package is eligible
            let pkg = Package(id: UUID(), url: "1")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg, defaultBranch: "default").create(on: app.db).wait()
            try Version(package: pkg,
                        reference: .tag(.init(1, 2, 3)),
                        packageName: "1",
                        commitDate: Date(timeIntervalSince1970: 0)).save(on: app.db).wait()
        }
        do {  // 2nd package is ineligible, because it has a branch reference
            let pkg = Package(id: UUID(), url: "2")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg, defaultBranch: "default").create(on: app.db).wait()
            try Version(package: pkg,
                        reference: .branch("default"),
                        packageName: "2",
                        commitDate: Date(timeIntervalSince1970: 0)).save(on: app.db).wait()
        }
        do {  // 3rd package is ineligible, because it has no package name
            let pkg = Package(id: UUID(), url: "3")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg, defaultBranch: "default").create(on: app.db).wait()
            try Version(package: pkg,
                        reference: .branch("default"),
                        commitDate: Date(timeIntervalSince1970: 0)).save(on: app.db).wait()
        }
        do {  // 4th package is ineligible, because it has no reference
            let pkg = Package(id: UUID(), url: "4")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg, defaultBranch: "default").create(on: app.db).wait()
            try Version(package: pkg,
                        packageName: "4",
                        commitDate: Date(timeIntervalSince1970: 0)).save(on: app.db).wait()
        }
        do {  // 5th package is eligible - should come before 1st because of more recent commit date
            let pkg = Package(id: UUID(), url: "5")
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg, defaultBranch: "default").create(on: app.db).wait()
            try Version(package: pkg,
                        reference: .tag(.init(1, 2, 3)),
                        packageName: "5",
                        commitDate: Date(timeIntervalSince1970: 1)).save(on: app.db).wait()
        }

        // make sure to refresh the materialized view
        try RecentRelease.refresh(on: app.db).wait()

        // MUT
        let res = try RecentRelease.fetch(on: app.db).wait()

        // validate
        XCTAssertEqual(res.map(\.packageName), ["5", "1"])
    }
}
