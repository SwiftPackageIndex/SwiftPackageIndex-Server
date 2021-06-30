extension KeywordShow {
    struct Model {
        var keyword: String
        var packages: [PackageInfo]

        internal init(
            keyword: String,
            packages: [PackageInfo]) {
            self.keyword = keyword
            self.packages = packages
        }
    }
}
