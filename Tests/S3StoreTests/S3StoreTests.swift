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

@testable import S3Store

import Testing


@Suite struct S3StoreTests {

    @Test func Key_path() throws {
        do {
            let key = S3Store.Key(bucket: "bucket", path: "foo/bar")
            #expect(key.path == "foo/bar")
        }
        do {
            let key = S3Store.Key(bucket: "bucket", path: "/foo/bar")
            #expect(key.path == "foo/bar")
        }
        do {
            let key = S3Store.Key(bucket: "bucket", path: "//foo/bar")
            #expect(key.path == "foo/bar")
        }
    }

    @Test func Key_objectUrl() throws {
        let key = S3Store.Key(bucket: "bucket", path: "foo/bar")
        #expect(key.objectUrl == "https://bucket.s3.us-east-2.amazonaws.com/foo/bar")
    }

    @Test func Key_s3Uri() throws {
        let key = S3Store.Key(bucket: "bucket", path: "foo/bar")
        #expect(key.s3Uri == "s3://bucket/foo/bar")
    }

}
