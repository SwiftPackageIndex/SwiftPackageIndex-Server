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

import Dependencies
import DependenciesMacros
import IssueReporting
import Vapor


@DependencyClient
struct FileManagerClient {
    var attributesOfItem: @Sendable (_ atPath: String) throws -> [FileAttributeKey : Any]
    var checkoutsDirectory: @Sendable () -> String = { reportIssue("checkoutsDirectory"); return "SPI-checkouts" }
    var contents: @Sendable (_ atPath: String) -> Data?
    var contentsOfDirectory: @Sendable (_ atPath: String) throws -> [String]
    var createDirectory: @Sendable (_ atPath: String, _ withIntermediateDirectories: Bool, _ attributes: [FileAttributeKey : Any]?) throws -> Void
    var fileExists: @Sendable (_ atPath: String) -> Bool = { reportIssue("fileExists"); return Foundation.FileManager.default.fileExists(atPath: $0) }
    var removeItem: @Sendable (_ atPath: String) throws -> Void
    var workingDirectory: @Sendable () -> String = { reportIssue("workingDirectory"); return "" }
}


extension FileManagerClient {
    func cacheDirectoryPath(for package: Package) -> String? {
        guard let dirname = package.cacheDirectoryName else { return nil }
        return checkoutsDirectory() + "/" + dirname
    }
}


extension FileManagerClient: DependencyKey {
    static var liveValue: Self {
        .init(
            attributesOfItem: { try Foundation.FileManager.default.attributesOfItem(atPath: $0) },
            checkoutsDirectory: { Environment.get("CHECKOUTS_DIR") ?? DirectoryConfiguration.detect().workingDirectory + "SPI-checkouts" },
            contents: { Foundation.FileManager.default.contents(atPath: $0) },
            contentsOfDirectory: { try Foundation.FileManager.default.contentsOfDirectory(atPath: $0) },
            createDirectory: { try Foundation.FileManager.default.createDirectory(atPath: $0, withIntermediateDirectories: $1, attributes: $2) },
            fileExists: { Foundation.FileManager.default.fileExists(atPath: $0) },
            removeItem: { try Foundation.FileManager.default.removeItem(atPath: $0) },
            workingDirectory: { DirectoryConfiguration.detect().workingDirectory }
        )
    }
}


extension FileManagerClient: TestDependencyKey {
    static var testValue: Self {
        var mock = Self()
        // Override the `unimplemented` default because it is a very common dependency.
        mock.checkoutsDirectory = { "SPI-checkouts" }
        mock.workingDirectory = { DirectoryConfiguration.detect().workingDirectory }
        return mock
    }
}


extension DependencyValues {
    var fileManager: FileManagerClient {
        get { self[FileManagerClient.self] }
        set { self[FileManagerClient.self] = newValue }
    }
}
