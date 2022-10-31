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

import Fluent
import OhhAuth
import SemanticVersion
import Vapor


enum Twitter {

    private static let apiUrl: String = "https://api.twitter.com/1.1/statuses/update.json"
    private static let tweetMaxLength = 260  // exactly 280 is rejected, plus leave some room for unicode accounting oddities
    
    enum Error: LocalizedError {
        case invalidMessage
        case missingCredentials
        case postingDisabled
        case requestFailed(HTTPStatus, String)
    }

    struct Credentials {
        var apiKey: (key: String, secret: String)
        var accessToken: (key: String, secret: String)
    }

    static func post(client: Client, tweet: String) -> EventLoopFuture<Void> {
        guard let credentials = Current.twitterCredentials() else {
            return client.eventLoop.future(error: Error.missingCredentials)
        }
        let url: URL = URL(string: "\(apiUrl)?status=\(tweet.urlEncodedString())")!
        let signature = OhhAuth.calculateSignature(
            url: url,
            method: "POST",
            parameter: [:],
            consumerCredentials: credentials.apiKey,
            userCredentials: credentials.accessToken
        )

        var headers: HTTPHeaders = .init()
        headers.add(name: "Authorization", value: signature)
        headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
        return client.post(URI(string: url.absoluteString), headers: headers)
            .flatMapThrowing { response in
                guard response.status == .ok else {
                    throw Error.requestFailed(response.status, response.body?.asString() ?? "")
                }
            }
            .transform(to: ())
    }

}


// MARK:- Helpers to post package to firehose

extension Twitter {

    static func createMessage(preamble: String,
                              separator: String = "–",
                              summary: String? = nil,
                              url: String = "") -> String {
        let link = "\n\n\(url)"
        let separator = " \(separator) "
        let availableLength = tweetMaxLength - preamble.count - separator.count - link.count
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
                                  summary: String?) -> String {
        createMessage(preamble: "📦 \(repositoryOwnerName) just added a new package, \(packageName)",
                      summary: summary,
                      url: url)
    }

    static func versionUpdateMessage(packageName: String,
                                     repositoryOwnerName: String,
                                     url: String,
                                     version: SemanticVersion,
                                     summary: String?) -> String {
        createMessage(preamble: "⬆️ \(repositoryOwnerName) just released \(packageName) v\(version)",
                      summary: summary,
                      url: "\(url)#releases")
    }

    static func firehoseMessage(package: Joined<Package, Repository>,
                                version: Version) -> String? {
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
                            summary: package.repository?.summary)
        : versionUpdateMessage(packageName: packageName,
                               repositoryOwnerName: ownerName,
                               url: url,
                               version: semVer,
                               summary: package.repository?.summary)
    }

    static func postToFirehose(client: Client,
                               package: Joined<Package, Repository>,
                               version: Version) -> EventLoopFuture<Void> {
        guard Current.allowTwitterPosts() else {
            return client.eventLoop.future(error: Error.postingDisabled)
        }
        guard let message = firehoseMessage(package: package,
                                            version: version)
        else {
            return client.eventLoop.future(error: Error.invalidMessage)
        }
        return Current.twitterPostTweet(client, message)
    }

    static func postToFirehose(client: Client,
                               package: Joined<Package, Repository>,
                               versions: [Version]) -> EventLoopFuture<Void> {
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
        return versions.map {
            postToFirehose(client: client,
                           package: package,
                           version: $0)
        }
        .flatten(on: client.eventLoop)
    }

}


private extension String {
    func urlEncodedString() -> String {
        var allowedCharacterSet: CharacterSet = .urlQueryAllowed
        allowedCharacterSet.remove(charactersIn: "\n:#/?@!$&'()*+,;=")
        allowedCharacterSet.insert(charactersIn: "[]")
        return self.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? ""
    }
}
