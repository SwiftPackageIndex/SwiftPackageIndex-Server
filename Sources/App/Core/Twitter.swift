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
        var consumer: (key: String, secret: String)
        var user: (key: String, secret: String)
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


// MARK:- Helpers to post package to firehose

extension Twitter {

    static func buildFirehosePost(packageName: String,
                                  url: String,
                                  version: SemanticVersion,
                                  summary: String) -> String {
        "\(packageName) just released version \(version) – \(summary)\n\n\(url)"
    }

    static func postToFirehose(client: Client, package: Package) -> EventLoopFuture<Void> {

        // FIXME
        let message = buildFirehosePost(packageName: "foo",
                                        url: "url",
                                        version: .init(1, 2, 3),
                                        summary: "summary")

        return Current.twitterPostTweet(client, message)
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
