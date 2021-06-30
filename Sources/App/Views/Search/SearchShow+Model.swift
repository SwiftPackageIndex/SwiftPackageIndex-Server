enum SearchShow {

    struct Model {
        var page: Int
        var query: String
        var response: Response
        
        internal init(page: Int, query: String, response: Search.Response) {
            self.page = page
            self.query = query
            self.response = Model.Response(response: response)
        }

        struct Response {
            var hasMoreResults: Bool
            var results: [Model.Result]

            init(response: Search.Response) {
                self.hasMoreResults = response.hasMoreResults
                self.results = response.results.compactMap(Model.Result.init)
            }
        }

        struct Result {
            var title: String
            var summary: String?
            var footer: String
            var link: String

            init?(result: Search.Result) {
                switch result {
                    case let .author(res):
                        title = "✍️ \(res.name)"
                        link = SiteURL.author(.value(res.name)).relativeURL()
                        footer = "Author results"
                    case let .keyword(res):
                        title = "🏷 \(res.keyword)"
                        link = SiteURL.keywords(.value(res.keyword)).relativeURL()
                        footer = "Keyword results"
                    case let .package(pkg):
                        guard let packageURL = pkg.packageURL,
                              let repositoryName = pkg.repositoryName,
                              let repositoryOwner = pkg.repositoryOwner
                        else { return nil }
                        title = pkg.packageName ?? "Unknown Package"
                        summary = pkg.summary
                        footer = "\(repositoryOwner)/\(repositoryName)"
                        link = packageURL
                }
            }
        }
    }

}
