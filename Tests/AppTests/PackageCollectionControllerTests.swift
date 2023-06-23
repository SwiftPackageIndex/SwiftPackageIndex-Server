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
import SnapshotTesting
import XCTVapor


class PackageCollectionControllerTests: AppTestCase {

    func test_owner_request() throws {
        try XCTSkipIf(!isRunningInCI && Current.collectionSigningPrivateKey() == nil, "Skip test for local user due to unset COLLECTION_SIGNING_PRIVATE_KEY env variable")
        // setup
        Current.date = { .t0 }
        let p = try savePackage(on: app.db, "https://github.com/foo/1")
        do {
            let v = try Version(id: UUID(),
                                package: p,
                                packageName: "P1-main",
                                reference: .branch("main"),
                                toolsVersion: "5.0")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib")
                .save(on: app.db).wait()
        }
        do {
            let v = try Version(id: UUID(),
                                package: p,
                                latest: .release,
                                packageName: "P1-tag",
                                reference: .tag(1, 2, 3),
                                toolsVersion: "5.1")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t1"])
                .save(on: app.db).wait()
            try Build(version: v,
                      platform: .iOS,
                      status: .ok,
                      swiftVersion: .init(5, 6, 0)).save(on: app.db).wait()
            try Target(version: v, name: "t1").save(on: app.db).wait()
        }
        try Repository(package: p,
                       defaultBranch: "main",
                       license: .mit,
                       licenseUrl: "https://foo/mit",
                       owner: "foo",
                       summary: "summary 1").create(on: app.db).wait()

        // MUT
        try app.test(
            .GET,
            "foo/collection.json",
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .ok)
                let json = try res.content.decode(PackageCollection.self)
                // See https://github.com/pointfreeco/swift-snapshot-testing/discussions/739 for why this is conditional
#if os(macOS)
                assertSnapshot(matching: json, as: .json(encoder), named: "macos")
#elseif os(Linux)
                assertSnapshot(matching: json, as: .json(encoder), named: "linux")
#endif
            })
    }

    func test_nonexisting_404() throws {
        // Ensure a request for a non-existing collection returns a 404
        // MUT
        try app.test(
            .GET,
            "foo/collection.json",
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .notFound)
            })
    }

}


extension PackageCollectionControllerTests {
    var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }
}
