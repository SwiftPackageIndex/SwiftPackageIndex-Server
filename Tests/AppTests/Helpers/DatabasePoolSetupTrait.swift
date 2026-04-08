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

import Testing
import Foundation


struct DatabasePoolSetupTrait: SuiteTrait, TestScoping {
    func provideScope(for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {

#if os(macOS)
        // sas 2026-04-07: Setting the working directory in the scheme is broken in Xcode 26.4.
        // Since we need to read .env files, we need to change the working directory manually for now as a work-around.
        _ = FileManager.default.changeCurrentDirectoryPath(
            URL(filePath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .path(percentEncoded: false)
        )
#endif

        try await DatabasePool.shared.setUp()
        try await function()
        try await DatabasePool.shared.tearDown()
    }
}


extension SuiteTrait where Self == DatabasePoolSetupTrait {
    static var setupDatabasePool: Self {
        Self()
    }
}
