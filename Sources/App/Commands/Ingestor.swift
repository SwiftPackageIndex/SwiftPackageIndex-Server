import Vapor
import Fluent


enum Github {
    struct License: Decodable {
        var key: String
    }
    struct Parent: Decodable {
        var cloneUrl: String
        var fullName: String
        var url: String
    }
    struct Repository: Decodable {
        var defaultBranch: String
        var description: String
        var forksCount: Int
        var license: License
        var stargazersCount: Int
        var parent: Parent?
    }

    static func fetchRepository(client: Client, owner: String, name: String) -> EventLoopFuture<Repository> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // Set User-Agent or we get a 403
        // https://developer.github.com/v3/#user-agent-required
        let headers: HTTPHeaders = .init([("User-Agent","SPI-Server")])

        let url = URI(string: "https://api.github.com/repos/\(owner)/\(name)")
        let request = client
            .get(url, headers: headers)
            .flatMapThrowing { try $0.content.decode(Repository.self, using: decoder) }
        return request
    }
}


struct IngestorCommand: Command {
    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?
    }

    var help: String {
        "Ingests packages"
    }

    func run(using context: CommandContext, signature: Signature) throws {
        //        let limit = signature.limit
        context.console.print("Ingesting ...")

        // for selected packages:
        // - fetch meta data
        //   - description
        //   - license
        //   - stars
        //   - fork count
        //   - forkedFrom (parent)

        let client = context.application.client
        let owner = "finestructure"
        //        let name = "SwiftPMLibrary"
        let name = "Gala"

        let request = Github.fetchRepository(client: client, owner: owner, name: name)
        let repo = try request.wait()
        dump(repo)
    }

}
