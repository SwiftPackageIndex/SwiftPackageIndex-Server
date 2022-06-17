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

import XCTest

@testable import S3DocArchives


class S3DocArchivesTests: XCTestCase {

    func test_parse() throws {
        let docs = keys.compactMap { try? DocArchive.path.parse($0) }
        XCTAssertEqual(docs, [
            .init(owner: "apple", repository: "swift-docc", ref: "main", product: "docc"),
            .init(owner: "apple", repository: "swift-docc", ref: "main", product: "swiftdocc"),
        ])
    }

    func test_archivesGroupedByRef() {
        let mainP1 = DocArchive.mock("foo", "bar", "main", "p1", "P1")
        let v123P1 = DocArchive.mock("foo", "bar", "1.2.3", "p1", "P1")
        let v123P2 = DocArchive.mock("foo", "bar", "1.2.3", "p2", "P2")
        let archives: [DocArchive] = [mainP1, v123P1, v123P2]
        XCTAssertEqual(archives.archivesGroupedByRef(), [
            "main": [mainP1],
            "1.2.3": [v123P1, v123P2]
        ])
    }

}


private let keys = [
    "apple/swift-docc/main/css/documentation-topic.de084985.css",
    "apple/swift-docc/main/css/documentation-topic~topic~tutorials-overview.67b822e0.css",
    "apple/swift-docc/main/css/index.47bc740e.css",
    "apple/swift-docc/main/css/topic.2eb01958.css",
    "apple/swift-docc/main/css/tutorials-overview.8754eb09.css",
    "apple/swift-docc/main/documentation/docc/adding-structure-to-your-documentation-pages/index.html",
    "apple/swift-docc/main/documentation/docc/adding-supplemental-content-to-a-documentation-catalog/index.html",
    "apple/swift-docc/main/documentation/docc/index.html",
    "apple/swift-docc/main/documentation/docc/intro/index.html",
    "apple/swift-docc/main/documentation/docc/justification/index.html",
    "apple/swift-docc/main/documentation/swiftdocc/implementationsgroup/references/index.html",
    "apple/swift-docc/main/documentation/swiftdocc/index.html",
    "apple/swift-docc/main/documentation/swiftdocc/indexable/index.html",
    "apple/swift-docc/main/documentation/swiftdocc/indexable/indexingrecords(onpage:)/index.html",
    "apple/swift-docc/main/documentation/swiftdocc/indexingerror/describederror-implementations/index.html",
]
