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

import Dependencies
import SnapshotTesting
import XCTVapor


class PackageCollectionControllerTests: AppTestCase {

    func test_owner_request() async throws {
        try XCTSkipIf(!isRunningInCI && Current.collectionSigningPrivateKey() == nil, "Skip test for local user due to unset COLLECTION_SIGNING_PRIVATE_KEY env variable")
        try await withDependencies {
            $0.date.now = .t0
            $0.environment.collectionSigningCertificateChain = EnvironmentClient.liveValue.collectionSigningCertificateChain
        } operation: {
            let p = try await savePackage(on: app.db, "https://github.com/foo/1")
            do {
                let v = try Version(id: UUID(),
                                    package: p,
                                    packageName: "P1-main",
                                    reference: .branch("main"),
                                    toolsVersion: "5.0")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "P1Lib")
                    .save(on: app.db)
            }
            do {
                let v = try Version(id: UUID(),
                                    package: p,
                                    latest: .release,
                                    packageName: "P1-tag",
                                    reference: .tag(1, 2, 3),
                                    toolsVersion: "5.1")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t1"])
                    .save(on: app.db)
                try await Build(version: v,
                                platform: .iOS,
                                status: .ok,
                                swiftVersion: .init(5, 6, 0)).save(on: app.db)
                try await Target(version: v, name: "t1").save(on: app.db)
            }
            try await Repository(package: p,
                                 defaultBranch: "main",
                                 license: .mit,
                                 licenseUrl: "https://foo/mit",
                                 owner: "foo",
                                 summary: "summary 1").create(on: app.db)

            // MUT
            let encoder = self.encoder
            try await app.test(
                .GET,
                "foo/collection.json",
                afterResponse: { @MainActor res async throws in
                    // validation
                    XCTAssertEqual(res.status, .ok)
                    let json = try res.content.decode(PackageCollection.self)
                    assertSnapshot(of: json, as: .json(encoder))
                })
        }
    }

    func test_custom_request() async throws {
        try XCTSkipIf(!isRunningInCI && Current.collectionSigningPrivateKey() == nil, "Skip test for local user due to unset COLLECTION_SIGNING_PRIVATE_KEY env variable")
        try await withDependencies {
            $0.date.now = .t0
            $0.environment.collectionSigningCertificateChain = EnvironmentClient.liveValue.collectionSigningCertificateChain
        } operation: {
            let p = try await savePackage(on: app.db, "https://github.com/foo/1")
            do {
                let v = try Version(id: UUID(),
                                    package: p,
                                    packageName: "P1-main",
                                    reference: .branch("main"),
                                    toolsVersion: "5.0")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "P1Lib")
                    .save(on: app.db)
            }
            do {
                let v = try Version(id: UUID(),
                                    package: p,
                                    latest: .release,
                                    packageName: "P1-tag",
                                    reference: .tag(1, 2, 3),
                                    toolsVersion: "5.1")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t1"])
                    .save(on: app.db)
                try await Build(version: v,
                                platform: .iOS,
                                status: .ok,
                                swiftVersion: .init(5, 6, 0)).save(on: app.db)
                try await Target(version: v, name: "t1").save(on: app.db)
            }
            try await Repository(package: p,
                                 defaultBranch: "main",
                                 license: .mit,
                                 licenseUrl: "https://foo/mit",
                                 owner: "foo",
                                 summary: "summary 1").create(on: app.db)
            let collection = CustomCollection(id: .id2, .init(key: "custom-collection",
                                                              name: "Custom Collection",
                                                              url: "https://github.com/foo/bar/list.json"))
            try await collection.save(on: app.db)
            try await collection.$packages.attach(p, on: app.db)

            // MUT
            let encoder = self.encoder
            try await app.test(
                .GET,
                "collections/custom-collection/collection.json",
                afterResponse: { @MainActor res async throws in
                    // validation
                    XCTAssertEqual(res.status, .ok)
                    let json = try res.content.decode(PackageCollection.self)
                    assertSnapshot(of: json, as: .json(encoder))
                })
        }
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
