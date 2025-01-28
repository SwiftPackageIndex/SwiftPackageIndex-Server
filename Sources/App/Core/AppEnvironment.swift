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

import AsyncHTTPClient
import S3Store
import SPIManifest
import ShellOut
import Vapor
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif


struct AppEnvironment: Sendable {
    var fileManager: FileManager
    var git: Git
    var logger: @Sendable () -> Logger
    var setLogger: @Sendable (Logger) -> Void
    var shell: Shell
}


extension AppEnvironment {
    nonisolated(unsafe) static var logger: Logger!

    static let live = AppEnvironment(
        fileManager: .live,
        git: .live,
        logger: { logger },
        setLogger: { logger in Self.logger = logger },
        shell: .live
    )
}


struct FileManager: Sendable {
    var createDirectory: @Sendable (String, Bool, [FileAttributeKey : Any]?) throws -> Void
    var fileExists: @Sendable (String) -> Bool
    var removeItem: @Sendable (_ path: String) throws -> Void
    var workingDirectory: @Sendable () -> String

    // pass-through methods to preserve argument labels
    func createDirectory(atPath path: String,
                         withIntermediateDirectories createIntermediates: Bool,
                         attributes: [FileAttributeKey : Any]?) throws {
        try createDirectory(path, createIntermediates, attributes)
    }
    func fileExists(atPath path: String) -> Bool { fileExists(path) }
    func removeItem(atPath path: String) throws { try removeItem(path) }

    static let live: Self = .init(
        createDirectory: { try Foundation.FileManager.default.createDirectory(atPath: $0, withIntermediateDirectories: $1, attributes: $2) },
        fileExists: { Foundation.FileManager.default.fileExists(atPath: $0) },
        removeItem: { try Foundation.FileManager.default.removeItem(atPath: $0) },
        workingDirectory: { DirectoryConfiguration.detect().workingDirectory }
    )
}


struct Git: Sendable {
    var commitCount: @Sendable (String) async throws -> Int
    var firstCommitDate: @Sendable (String) async throws -> Date
    var lastCommitDate: @Sendable (String) async throws -> Date
    var getTags: @Sendable (String) async throws -> [Reference]
    var hasBranch: @Sendable (Reference, String) async throws -> Bool
    var revisionInfo: @Sendable (Reference, String) async throws -> RevisionInfo
    var shortlog: @Sendable (String) async throws -> String

    static let live: Self = .init(
        commitCount: { path in try await commitCount(at: path) },
        firstCommitDate: { path in try await firstCommitDate(at: path) },
        lastCommitDate: { path in try await lastCommitDate(at: path) },
        getTags: { path in try await getTags(at: path) },
        hasBranch: { ref, path in try await hasBranch(ref, at: path) },
        revisionInfo: { ref, path in try await revisionInfo(ref, at: path) },
        shortlog: { path in try await shortlog(at: path) }
    )
}


struct Shell: Sendable {
    var run: @Sendable (ShellOutCommand, String) async throws -> String

    // also provide pass-through methods to preserve argument labels
    @discardableResult
    func run(command: ShellOutCommand, at path: String = ".") async throws -> String {
        do {
            return try await run(command, path)
        } catch {
            // re-package error to capture more information
            throw AppError.shellCommandFailed(command.description, path, error.localizedDescription)
        }
    }

    static let live: Self = .init(
        run: {
            let res = try await ShellOut.shellOut(to: $0, at: $1, logger: Current.logger())
            if !res.stderr.isEmpty {
                Current.logger().warning("stderr: \(res.stderr)")
            }
            return res.stdout
        }
    )
}


#if DEBUG
nonisolated(unsafe) var Current: AppEnvironment = .live
#else
let Current: AppEnvironment = .live
#endif
