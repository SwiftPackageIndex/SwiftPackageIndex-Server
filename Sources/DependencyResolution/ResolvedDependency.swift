// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

public struct ResolvedDependency: Codable, Equatable {
    public var packageName: String
    public var repositoryURL: String

    public init(packageName: String, repositoryURL: String) {
        self.packageName = packageName
        self.repositoryURL = repositoryURL
    }
}


public protocol FileManager {
    func contents(atPath: String) -> Data?
    func fileExists(atPath: String) -> Bool
}


extension Foundation.FileManager: FileManager { }


public func getResolvedDependencies(_ fileManager: FileManager = Foundation.FileManager.default, at path: String) -> [ResolvedDependency]? {
    //    object:
    //      pins:
    //        - package: String
    //          repositoryURL: URL
    //          state:
    //            branch: String?
    //            revision: CommitHash
    //            version: SemVer?
    //        - ...
    //      version: 1
    struct PackageResolved: Decodable {
        var object: Object

        struct Object: Decodable {
            var pins: [Pin]

            struct Pin: Decodable {
                var package: String
                var repositoryURL: URL
            }
        }
    }

    let filePath = path + "/Package.resolved"
    guard fileManager.fileExists(atPath: filePath),
          let json = fileManager.contents(atPath: filePath),
          let packageResolved = try? JSONDecoder()
            .decode(PackageResolved.self, from: json)
    else {
        return nil
    }
    return packageResolved.object.pins.map {
        ResolvedDependency(
            packageName: $0.package,
            repositoryURL: $0.repositoryURL.absoluteString
        )
    }
}
