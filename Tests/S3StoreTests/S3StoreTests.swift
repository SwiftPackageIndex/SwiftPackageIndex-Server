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

@testable import S3Store


final class S3StoreTests: XCTestCase {

    func test_copy() async throws {
#warning("FIXME: update test")
        let keyId = try XCTUnwrap(ProcessInfo.processInfo.environment["LIVE_AWS_ACCESS_KEY_ID"])
        let secret = try XCTUnwrap(ProcessInfo.processInfo.environment["LIVE_AWS_SECRET_ACCESS_KEY"])
        let store = S3Store(credentials: .init(keyId: keyId, secret: secret))
        let path = fixturesDirectory().appendingPathComponent("README.md").path

        // MUT
        try await store.copy(from: path, to: .init(bucket: "spi-dev-readmes", path: "foo/bar/README.md"))
        try await store.copy(from: path, to: .init(bucket: "spi-dev-readmes", path: "foo/bar/README.md"))
        try await store.copy(from: path, to: .init(bucket: "spi-dev-readmes", path: "/foo/bar/README.md"))
    }

}


private func fixturesDirectory(path: String = #file) -> URL {
    let url = URL(fileURLWithPath: path)
    let testsDir = url.deletingLastPathComponent()
    return testsDir.appendingPathComponent("Fixtures")
}
