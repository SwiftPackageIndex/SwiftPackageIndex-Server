enum SearchShow {

    struct Model {
        var query: String
        var results: [Search.Record]
        
        internal init(query: String, results: [Search.Record]) {
            self.query = query
            self.results = results
        }
    }

}
