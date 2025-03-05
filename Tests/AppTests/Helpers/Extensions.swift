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

@testable import App
import Fluent


// MARK: - Useful extensions


extension Foundation.URL: Swift.ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        precondition(!value.isEmpty, "cannot convert empty string to URL")
        self = URL(string: value)!
    }
}


extension String {
    var url: URL {
        URL(string: self)!
    }
}


extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}


extension String {
    var asGithubUrl: String { "https://github.com/foo/\(self)" }
    var asSwiftVersion: SwiftVersion { SwiftVersion(self)! }
}


extension Array where Element == String {
    var asURLs: [URL] { compactMap(URL.init(string:)) }
    var asGithubUrls: Self { map(\.asGithubUrl) }
    var asSwiftVersions: [SwiftVersion] { map(\.asSwiftVersion) }
}


extension App.AppError: Swift.Equatable {
    public static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
            case let (.envVariableNotSet(v1), .envVariableNotSet(v2)):
                return v1 == v2
            case let (.genericError(id1, v1), .genericError(id2, v2)):
                return (id1, v1) == (id2, v2)
            case let (.invalidPackageCachePath(id1, v1), .invalidPackageCachePath(id2, v2)):
                return (id1, v1) == (id2, v2)
            case let (.invalidRevision(id1, v1), .invalidRevision(id2, v2)):
                return (id1, v1) == (id2, v2)
            default:
                return false
        }
    }
}
