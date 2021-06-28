struct PackageInfo {
    var title: String
    var description: String
    var url: String
}

extension PackageInfo {
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
}
