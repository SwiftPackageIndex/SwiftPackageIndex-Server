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

import Foundation


class TempDir {
    let path: String
    let fileManager: Foundation.FileManager

    init(fileManager: Foundation.FileManager = .default) throws {
        self.fileManager = fileManager
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        path = tempDir.path
        try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        precondition(fileManager.fileExists(atPath: path), "failed to create temp dir")
    }

    deinit {
        do {
            try fileManager.removeItem(atPath: path)
        } catch {
            print("⚠️ failed to delete temp directory: \(error.localizedDescription)")
        }
    }

    @discardableResult
    convenience init(body: (String) async throws -> Void) async throws {
        try self.init()
        try await body(path)
    }
}


func withTempDir<T>(body: (String) throws -> T) throws -> T {
    let tmp = try TempDir()
    return try body(tmp.path)
}
