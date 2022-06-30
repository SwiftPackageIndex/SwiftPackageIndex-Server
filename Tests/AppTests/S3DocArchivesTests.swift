// Copyright 2020-2022 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import SotoS3
import XCTest

@testable import S3DocArchives


class S3DocArchivesTests: XCTestCase {

    func test_getTitle() async throws {
        // setup
        Current.getFileContent = { _, key in
            struct UnexpectedInput: Error {}
            if key.bucket == "bucket",
               key.path == "SwiftPackageIndex/SemanticVersion/main/data/documentation/semanticversion.json" {
                return try? fixtureData(for: "s3-semanticversion.json")
            }
            throw UnexpectedInput()
        }
        let client = AWSClient(credentialProvider: .static(accessKeyId: "",
                                                           secretAccessKey: ""),
                               httpClientProvider: .createNew)
        defer { try? client.syncShutdown() }
        let s3 = S3(client: client, region: .useast2)

        let path = DocArchive.Path(owner: "SwiftPackageIndex",
                                   repository: "SemanticVersion",
                                   ref: "main",
                                   product: "semanticversion")

        // MUT
        let title = await DocArchive.getTitle(s3: s3, bucket: "bucket", path: path)

        // validation
        XCTAssertEqual(title, "SemanticVersion")
    }

    func test_fetchAll() async throws {

    }

    func test_parse() throws {
        let docs = prefixes.compactMap { try? DocArchive.path.parse($0) }
        XCTAssertEqual(docs, [
            .init(owner: "apple", repository: "swift-docc", ref: "main", product: "docc"),
            .init(owner: "apple", repository: "swift-docc", ref: "main", product: "swiftdocc"),
            .init(owner: "apple", repository: "swift-docc", ref: "1.2.3", product: "docc"),
        ])
    }

}


private let prefixes = [
    "apple/swift-docc/main/documentation/docc/",
    "apple/swift-docc/main/documentation/swiftdocc/",
    "apple/swift-docc/1.2.3/documentation/docc/",
    "foo/bar",                         // too short
    "foo/bar/documentation/bar/",      // no ref
    "foo/bar/1.2.3/documentation/bar"  // no trailing slash
]
