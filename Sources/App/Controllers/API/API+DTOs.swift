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

import DependencyResolution


extension API {
    struct PostBuildTriggerDTO: Codable {
        var platform: Build.Platform
        var swiftVersion: SwiftVersion
    }

    struct PostBuildReportDTO: Codable {
        var buildCommand: String?
        var buildId: UUID
        var jobUrl: String?
        var logUrl: String?
        var platform: Build.Platform
        var resolvedDependencies: [ResolvedDependency]?
        var runnerId: String?
        var status: Build.Status
        var swiftVersion: SwiftVersion
    }

    struct PostDocReportDTO: Codable {
        var docArchives: [DocArchive]?
        var error: String?
        var fileCount: Int?
        var logUrl: String?
        var mbSize: Int?
        var status: DocUpload.Status
    }
}
