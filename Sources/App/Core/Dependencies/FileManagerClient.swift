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


@DependencyClient
struct FileManagerClient {
    var attributesOfItem: @Sendable (_ atPath: String) throws -> [FileAttributeKey : Any]
    var contents: @Sendable (_ atPath: String) -> Data?
}


extension FileManagerClient: DependencyKey {
    static var liveValue: Self {
        .init(
            attributesOfItem: { try Foundation.FileManager.default.attributesOfItem(atPath: $0) },
            contents: { Foundation.FileManager.default.contents(atPath: $0) }
        )
    }
}


extension FileManagerClient: TestDependencyKey {
    static var testValue: Self { .init() }
}


extension DependencyValues {
    var fileManager: FileManagerClient {
        get { self[FileManagerClient.self] }
        set { self[FileManagerClient.self] = newValue }
    }
}
