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
import Vapor


struct ResourceReloadIdentifier {
    static var value: String {
        @Dependency(\.environment) var environment
        // In staging or production appVersion will be set to a commit hash or a tag name.
        // It will only ever be nil when running in a local development environment.
        if let appVersion = environment.appVersion() {
            return appVersion
        } else {
            // Return the date of the most recently modified between the JavaScript and CSS resources.
            let jsModificationDate = modificationDate(forLocalResource: "main.js")
            let cssModificationDate = modificationDate(forLocalResource: "main.css")
            let latestModificationDate = max(jsModificationDate, cssModificationDate)
            return String(Int(latestModificationDate.timeIntervalSince1970))
        }
    }

    private static func modificationDate(forLocalResource resource: String) -> Date {
        @Dependency(\.date.now) var now
        @Dependency(\.fileManager) var fileManager
        let pathToPublic = DirectoryConfiguration.detect().publicDirectory
        let url = URL(fileURLWithPath: pathToPublic + resource)

        // Assume the file has been modified *now* if the file can't be found.
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        else { return now }

        // Also assume the file is modified now if the attribute doesn't exist.
        let modificationDate = attributes[FileAttributeKey.modificationDate] as? Date
        return modificationDate ?? now
    }
}
