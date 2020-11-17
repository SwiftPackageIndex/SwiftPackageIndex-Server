import OhhAuth
import Vapor


enum Twitter {

    enum Error: LocalizedError {
        case invalidMessage
        case missingCredentials
    }

    static func buildFirehosePost(package: Package) -> String? {
        guard let repo = package.repository,
              let version = Package.findRelease(package.versions),
              let semVer = version.reference?.semVer,
              let repoName = repo.name
        else { return nil }
        
        // summary = '- repo summary goes here' or ''
        let summary = repo.summary?.isEmpty != false ? "" : "- " + (repo.summary ?? "")
        let url = SiteURL.package(.value(repo.owner ?? ""), .value(repoName), .none).absoluteURL()
        
        return "\(repoName) just released v\(semVer.description) \(summary)\n\n\(url)"
    }
    
    static func postToFirehose(client: Client, package: Package) -> EventLoopFuture<Void> {
        guard let message = buildFirehosePost(package: package) else {
            return client.eventLoop.future(error: Error.invalidMessage)
        }

        return Current.twitterPostTweet(client, message)
    }
}


// MARK:- POST request

extension Twitter {

    private static let apiUrl: String = "https://api.twitter.com/1.1/statuses/update.json"

    struct Credentials {
        var consumer: (key: String, secret: String)
        var user: (key: String, secret: String)
    }

    // FIXME: add to AppEnvironment
    static func post(client: Client,
                     tweet: String) -> EventLoopFuture<Void> {
        guard let credentials = Current.twitterCredentials() else {
            return client.eventLoop.future(error: Error.missingCredentials)
        }
        let url: URL = URL(string: "\(apiUrl)?status=\(tweet.urlEncodedString())")!
        let signature = OhhAuth.calculateSignature(
            url: url,
            method: "POST",
            parameter: [:],
            consumerCredentials: credentials.consumer,
            userCredentials: credentials.user
        )

        var headers: HTTPHeaders = .init()
        headers.add(name: "Authorization", value: signature)
        headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
        return client.post(URI(string: url.absoluteString), headers: headers)
            .transform(to: ())
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
