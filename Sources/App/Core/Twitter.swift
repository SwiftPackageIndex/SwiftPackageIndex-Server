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
            guard let summary = summary else { return "" }
            let ellipsis = "…"
            return summary.count < availableLength
                ? separator + summary
                : separator + String(summary.prefix(availableLength - ellipsis.count)) + ellipsis
        }()

        return preamble + description + link
    }

    static func newPackageMessage(packageName: String,
                                  repositoryOwner: String,
                                  url: String,
                                  summary: String?) -> String {
        createMessage(preamble: "New package: \(packageName) by \(repositoryOwner)",
                      summary: summary,
                      url: url)
    }

    static func versionUpdateMessage(packageName: String,
                                     repositoryOwner: String,
                                     url: String,
                                     version: SemanticVersion,
                                     summary: String?) -> String {
        createMessage(preamble: "\(repositoryOwner) just released \(packageName) v\(version)",
                      summary: summary,
                      url: url)
    }

    static func firehoseMessage(db: Database, for version: Version) -> EventLoopFuture<String?> {
        version.fetchPackage(db)
            .flatMap { pkg in
                pkg.fetchRepository(db).map { (pkg, $0) }
            }
            .map { pkg, repo in
                guard let packageName = version.packageName,
                      let repoName = repo?.name,
                      let owner = repo?.owner,
                      let semVer = version.reference?.semVer
                else { return nil }
                let url = SiteURL.package(.value(owner), .value(repoName), .none).absoluteURL()
                return pkg.isNew
                    ? newPackageMessage(packageName: packageName,
                                        repositoryOwner: owner,
                                        url: url,
                                        summary: repo?.summary ?? "")
                    : versionUpdateMessage(packageName: packageName,
                                           repositoryOwner: owner,
                                           url: url,
                                           version: semVer,
                                           summary: repo?.summary ?? "")
            }
    }

    static func postToFirehose(client: Client,
                               database: Database,
                               version: Version) -> EventLoopFuture<Void> {
        guard Current.allowTwitterPosts() else {
            return client.eventLoop.future(error: Error.postingDisabled)
        }
        return firehoseMessage(db: database, for: version)
            .flatMap {
                guard let message = $0 else {
                    return client.eventLoop.future(error: Error.invalidMessage)
                }
                return Current.twitterPostTweet(client, message)
            }
    }

    static func postToFirehose(client: Client,
                               database: Database,
                               package: Package,
                               versions: [Version]) -> EventLoopFuture<Void> {
        let (release, preRelease, defaultBranch) = package.findSignificantReleases()
        let idsLatest = [release, preRelease, defaultBranch].compactMap { $0?.id }
        // filter on versions with a tag and which are in the "latest" triple
        let versions = versions.filter { version in
            guard let reference = version.reference,
                  reference.isTag,
                  let id = version.id else { return false }
            return idsLatest.contains(id)
        }
        return versions.map {
            postToFirehose(client: client, database: database, version: $0)
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
