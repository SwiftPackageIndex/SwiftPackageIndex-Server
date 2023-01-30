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

import Vapor


struct DeleteBuildsCommand: Command {
    struct Signature: CommandSignature {
        @Option(name: "version-id", short: "v")
        var versionId: UUID?
        @Option(name: "package-id", short: "p")
        var packageId: UUID?
        @Option(name: "latest", short: "l", help: "release, pre_release, or default_branch")
        var latest: Version.Kind?
    }

    var help: String { "Delete build records" }

    func run(using context: CommandContext, signature: Signature) throws {

        switch (signature.versionId, signature.packageId) {
            case let (versionId?, .none):
                context.console.info("Deleting builds for version id \(versionId) ...")
                let count = try Build.delete(on: context.application.db,
                                             versionId: versionId).wait()
                context.console.info("Deleted \(pluralizedCount: count, singular: "record")")

            case let (.none, packageId?):
                context.console.info("Deleting builds for package id \(packageId) ...")
                let count: Int
                if let kind = signature.latest {
                    count = try Build.delete(on: context.application.db,
                                             packageId: packageId,
                                             versionKind: kind).wait()
                } else {
                    count = try Build.delete(on: context.application.db,
                                                 packageId: packageId).wait()
                }
                context.console.info("Deleted \(pluralizedCount: count, singular: "record")")

            case (.some, .some):
                context.console.error("Specift either 'version-id' or 'package-id' but not both")

            case (.none, .none):
                context.console.error("Specify either 'version-id' or 'package-id'")
        }
    }
}


extension Version.Kind: LosslessStringConvertible {
    init?(_ description: String) {
        self.init(rawValue: description)
    }

    var description: String {
        rawValue
    }
}
