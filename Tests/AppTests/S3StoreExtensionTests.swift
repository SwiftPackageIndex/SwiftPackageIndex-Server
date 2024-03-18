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

import XCTest

@testable import App

import S3Store

class S3StoreExtensionTests: XCTestCase {

    func test_Key_readme() throws {
        Current.awsReadmeBucket = { "awsReadmeBucket" }

        let imageKey = try S3Store.Key.readme(owner: "owner", repository: "repository",
                                              imageUrl: "https://example.com/image/example-image.png")
        XCTAssertEqual(imageKey.s3Uri, "s3://awsReadmeBucket/owner/repository/example-image.png")

        let readmeKey = try S3Store.Key.readme(owner: "owner", repository: "repository")
        XCTAssertEqual(readmeKey.s3Uri, "s3://awsReadmeBucket/owner/repository/readme.html")
    }

}
