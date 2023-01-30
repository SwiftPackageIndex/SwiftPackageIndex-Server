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

@testable import App

import Vapor


extension App.FileManager {
    static let mock = Self.mock(fileExists: true)
    static func mock(fileExists: Bool) -> Self {
        .init(
            attributesOfItem: { _ in [:] },
            contentsOfDirectory: { _ in [] },
            contents: { _ in .init() },
            checkoutsDirectory: { DirectoryConfiguration.detect().workingDirectory + "SPI-checkouts" },
            createDirectory: { path, _, _ in },
            fileExists: { path in fileExists },
            removeItem: { _ in },
            workingDirectory: { DirectoryConfiguration.detect().workingDirectory }
        )
    }
}
