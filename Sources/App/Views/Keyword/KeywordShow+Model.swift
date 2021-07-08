extension KeywordShow {
    struct Model {
        var keyword: String
        var packages: [PackageInfo]
        var page: Int
        var hasMoreResults: Bool

        internal init(keyword: String,
                      packages: [PackageInfo],
                      page: Int,
                      hasMoreResults: Bool) {
            self.keyword = keyword
            self.packages = packages
            self.page = page
            self.hasMoreResults = hasMoreResults
        }
    }
}
