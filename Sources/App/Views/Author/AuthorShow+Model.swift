extension AuthorShow {
    struct Model {
        var owner: String
        var packages: [PackageInfo]
        
        var count: Int {
            packages.count
        }
        
        internal init(owner: String,
                      packages: [PackageInfo]) {
            self.owner = owner
            self.packages = packages
        }
    }

    struct PackageInfo {
        var title: String
        var description: String
        var url: String

        init?(package: Package) {
            guard let repoName = package.repository?.name,
                  let repoDescription = package.repository?.summary,
                  let repoOwner = package.repository?.owner
            else {
                return nil
            }
            
            self.init(title: repoName,
                      description: repoDescription,
                      url: SiteURL.package(.value(repoOwner),
                                           .value(repoName),
                                           .none).relativeURL())
        }
        
        internal init(title: String,
                      description: String,
                      url: String) {
            self.title = title
            self.description = description
            self.url = url
        }
    }
}
