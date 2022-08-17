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

import Vapor


enum AppError: LocalizedError {
    case analysisError(Package.Id?, _ message: String)
    case envVariableNotSet(_ variable: String)
    case invalidPackageUrl(Package.Id?, _ url: String)
    case invalidPackageCachePath(Package.Id?, _ path: String)
    case unexistentPackageCacheDir(Package.Id?, _ path: String)
    case invalidRevision(Version.Id?, _ revision: String?)
    case metadataRequestFailed(Package.Id?, HTTPStatus, URI)
    case noValidVersions(Package.Id?, _ url: String)
    case shellCommandFailed(_ command: String, _ path: String, _ message: String)
    
    case genericError(Package.Id?, _ message: String)
    
    var localizedDescription: String {
        switch self {
            case let .analysisError(id, message):
                return "Analysis failed: \(message) (id: \(id))"
            case let .envVariableNotSet(value):
                return "Environment variable not set: \(value)"
            case let .invalidPackageUrl(id, value):
                return "Invalid packge URL: \(value) (id: \(id))"
            case let .invalidPackageCachePath(id, value):
                return "Invalid packge cache path: \(value) (id: \(id))"
            case let .unexistentPackageCacheDir(id, value):
            return "Package cache directory, \(value), does not exist: (id: \(id)"
            case let .invalidRevision(id, value):
                return "Invalid revision: \(value ?? "nil") (id: \(id))"
            case let .metadataRequestFailed(id, status, uri):
                return "Metadata request for URI '\(uri.description)' failed with status '\(status)'  (id: \(id))"
            case let .noValidVersions(id, value):
                return "No valid version found for package '\(value)' (id: \(id))"
            case let .shellCommandFailed(command, path, message):
                return """
                    Shell command failed:
                    command: "\(command)"
                    path:    "\(path)"
                    message: "\(message)"
                    """
            case let .genericError(.none, value):
                return "Error: \(value)"
            case let .genericError(id, value):
                return "Error: \(value) (id: \(id))"
        }
    }
    
    var errorDescription: String? {
        localizedDescription
    }
    
    enum Level: String, Codable, CaseIterable {
        case critical
        case error
        case warning
        case info
        case debug
    }
}


extension AppError.Level: Comparable {
    static func < (lhs: AppError.Level, rhs: AppError.Level) -> Bool {
        allCases.firstIndex(of: lhs)! > allCases.firstIndex(of: rhs)!
    }
}


extension AppError {
    static func report(_ client: Client, _ level: Level, _ error: Error) -> EventLoopFuture<Void> {
        guard level >= Current.rollbarLogLevel() else { return client.eventLoop.future() }
        return Rollbar.createItem(client: client,
                                  level: .init(level: level),
                                  message: error.localizedDescription)
    }
}
