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
        let docs = prefixes.compactMap { try? DocArchive.path.parse($0) }
        XCTAssertEqual(docs, [
            .init(owner: "apple", repository: "swift-docc", ref: "main", product: "docc"),
            .init(owner: "apple", repository: "swift-docc", ref: "main", product: "swiftdocc"),
            .init(owner: "apple", repository: "swift-docc", ref: "1.2.3", product: "docc"),
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


private let prefixes = [
    "apple/swift-docc/main/documentation/docc/",
    "apple/swift-docc/main/documentation/swiftdocc/",
    "apple/swift-docc/1.2.3/documentation/docc/",
    "foo/bar",                         // too short
    "foo/bar/documentation/bar/",      // no ref
    "foo/bar/1.2.3/documentation/bar"  // no trailing slash
]
