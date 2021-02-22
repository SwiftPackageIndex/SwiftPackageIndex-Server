enum SearchShow {

    struct Model {
        var page: Int
        var query: String
        var result: Search.Result
        
        internal init(page: Int, query: String, result: Search.Result) {
            self.page = page
            self.query = query
            self.result = result
        }
    }

}
