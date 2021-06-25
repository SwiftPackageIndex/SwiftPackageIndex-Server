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
            var packageId: Package.Id?
            var packageName: String
            var packageURL: String
            var repositoryName: String
            var repositoryOwner: String
            var summary: String?

            init?(result: Search.Result) {
                guard case let .package(pkg) = result else { return nil }
                guard let packageURL = pkg.packageURL else { return nil }
                guard let repositoryName = pkg.repositoryName else { return nil }
                guard let repositoryOwner = pkg.repositoryOwner else { return nil }

                self.packageId = pkg.packageId
                self.packageName = pkg.packageName ?? "Unknown Package"
                self.packageURL = packageURL
                self.repositoryName = repositoryName
                self.repositoryOwner = repositoryOwner
                self.summary = pkg.summary
            }
        }
    }

}
