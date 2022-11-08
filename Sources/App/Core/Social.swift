// Copyright 2020-2022 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import SemanticVersion
import Vapor


enum Social {

    enum Error: LocalizedError {
        case invalidMessage
        case missingCredentials
        case postingDisabled
        case requestFailed(HTTPStatus, String)
    }

    static func createMessage(preamble: String,
                              separator: String = "–",
                              summary: String? = nil,
                              url: String = "",
                              maxLength: Int) -> String {
        let link = "\n\n\(url)"
        let separator = " \(separator) "
        let availableLength = maxLength - preamble.count - separator.count - link.count
        let description: String = {
            guard let summary = summary?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !summary.isEmpty else { return "" }
            let ellipsis = "…"
            return summary.count < availableLength
                ? separator + summary
                : separator + String(summary.prefix(availableLength - ellipsis.count)) + ellipsis
        }()

        return preamble + description + link
    }

    static func newPackageMessage(packageName: String,
                                  repositoryOwnerName: String,
                                  url: String,
                                  summary: String?,
                                  maxLength: Int) -> String {
        createMessage(preamble: "📦 \(repositoryOwnerName) just added a new package, \(packageName)",
                      summary: summary,
                      url: url,
                      maxLength: maxLength)
    }

    static func versionUpdateMessage(packageName: String,
                                     repositoryOwnerName: String,
                                     url: String,
                                     version: SemanticVersion,
                                     summary: String?,
                                     maxLength: Int) -> String {
        createMessage(preamble: "⬆️ \(repositoryOwnerName) just released \(packageName) v\(version)",
                      summary: summary,
                      url: "\(url)#releases",
                      maxLength: maxLength)
    }

    static func firehoseMessage(package: Joined<Package, Repository>,
                                version: Version,
                                maxLength: Int) -> String? {
        guard let packageName = version.packageName,
              let repoName = package.repository?.name,
              let owner = package.repository?.owner,
              let ownerName = package.repository?.ownerDisplayName,
              let semVer = version.reference.semVer
        else { return nil }
        let url = SiteURL.package(.value(owner), .value(repoName), .none).absoluteURL()
        return package.model.isNew
        ? newPackageMessage(packageName: packageName,
                            repositoryOwnerName: ownerName,
                            url: url,
                            summary: package.repository?.summary,
                            maxLength: maxLength)
        : versionUpdateMessage(packageName: packageName,
                               repositoryOwnerName: ownerName,
                               url: url,
                               version: semVer,
                               summary: package.repository?.summary,
                               maxLength: maxLength)
    }

    static func postToFirehose(client: Client,
                               package: Joined<Package, Repository>,
                               version: Version) async throws {
        guard Current.allowTwitterPosts() else {
            throw Error.postingDisabled
        }
        guard let message = firehoseMessage(package: package,
                                            version: version,
                                            maxLength: Twitter.tweetMaxLength) else {
            throw Error.invalidMessage
        }
        try await Current.twitterPost(client, message)
    }

    static func postToFirehose(client: Client,
                               package: Joined<Package, Repository>,
                               versions: [Version]) async throws {
        let (release, preRelease, defaultBranch) = Package.findSignificantReleases(
            versions: versions,
            branch: package.repository?.defaultBranch
        )
        let idsLatest = [release, preRelease, defaultBranch].compactMap { $0?.id }
        // filter on versions with a tag and which are in the "latest" triple
        let versions = versions.filter { version in
            guard version.reference.isTag,
                  let id = version.id else { return false }
            return idsLatest.contains(id)
        }
        var firstError: Swift.Error? = nil
        for version in versions {
            // Try all posts and record first error, if any
            do {
                try await postToFirehose(client: client, package: package, version: version)
            } catch {
                if firstError != nil {
                    firstError = error
                }
            }
        }
        if let error = firstError {
            throw error
        }
    }

}
