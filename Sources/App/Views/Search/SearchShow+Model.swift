enum SearchShow {

    struct Model {
        var page: Int
        var query: String
        var result: Result
        
        internal init(page: Int, query: String, result: Search.Result) {
            self.page = page
            self.query = query
            self.result = Result(result: result)
        }

        struct Result {
            var hasMoreResults: Bool
            var results: [Record]

            init(result: Search.Result) {
                self.hasMoreResults = result.hasMoreResults
                self.results = result.results.compactMap(Record.init)
            }
        }

        struct Record {
            var packageId: Package.Id
            var packageName: String
            var packageURL: String
            var repositoryName: String
            var repositoryOwner: String
            var summary: String?

            init?(record: Search.Record) {
                guard let packageURL = record.packageURL else { return nil }
                guard let repositoryName = record.repositoryName else { return nil }
                guard let repositoryOwner = record.repositoryOwner else { return nil }

                self.packageId = record.packageId
                self.packageName = record.packageName ?? "Unknown Package"
                self.packageURL = packageURL
                self.repositoryName = repositoryName
                self.repositoryOwner = repositoryOwner
                self.summary = record.summary
            }
        }
    }

}
