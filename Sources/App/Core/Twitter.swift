import Fluent
import OhhAuth
import SemanticVersion
import Vapor


enum Twitter {

    enum Error: LocalizedError {
        case invalidMessage
        case missingCredentials
    }

    private static let apiUrl: String = "https://api.twitter.com/1.1/statuses/update.json"

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
            .transform(to: ())
    }

}


// MARK:- Helpers to post package to firehose

extension Twitter {

    static func firehostPost(repositoryOwner: String,
                             repositoryName: String,
                             url: String,
                             version: SemanticVersion,
                             summary: String?) -> String {
        """
        \(repositoryOwner) just released \(repositoryName) v\(version)\(summary.map { " – \($0)"} ?? "")

        \(url)
        """
    }

    static func firehostPost(db: Database, for version: Version) -> EventLoopFuture<String?> {
        version.fetchPackage(db)
            .flatMap { pkg in
                pkg.fetchRepository(db).map { (pkg, $0) }
            }
            .map { pkg, repo in
                guard let repoName = repo?.name,
                      let owner = repo?.owner,
                      let semVer = version.reference?.semVer
                else { return nil }
                let url = SiteURL.package(.value(owner), .value(repoName), .none).absoluteURL()
                return firehostPost(repositoryOwner: owner,
                                    repositoryName: repoName,
                                    url: url,
                                    version: semVer,
                                    summary: repo?.summary ?? "")
            }
    }

    static func postToFirehose(client: Client,
                               database: Database,
                               version: Version) -> EventLoopFuture<Void> {
        firehostPost(db: database, for: version)
            .flatMap {
                guard let message = $0 else {
                    return client.eventLoop.future(error: Error.invalidMessage)
                }
                return Current.twitterPostTweet(client, message)
            }
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
