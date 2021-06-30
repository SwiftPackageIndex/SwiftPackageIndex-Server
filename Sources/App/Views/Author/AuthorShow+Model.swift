extension AuthorShow {
    struct Model {
        var owner: String
        var ownerName: String
        var packages: [PackageInfo]
        
        internal init(
            owner: String,
            ownerName: String,
            packages: [PackageInfo]) {
            self.owner = owner
            self.ownerName = ownerName
            self.packages = packages
        }
    }
}
