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
                guard let packageURL = result.packageURL else { return nil }
                guard let repositoryName = result.repositoryName else { return nil }
                guard let repositoryOwner = result.repositoryOwner else { return nil }

                self.packageId = result.packageId
                self.packageName = result.packageName ?? "Unknown Package"
                self.packageURL = packageURL
                self.repositoryName = repositoryName
                self.repositoryOwner = repositoryOwner
                self.summary = result.summary
            }
        }
    }

}
