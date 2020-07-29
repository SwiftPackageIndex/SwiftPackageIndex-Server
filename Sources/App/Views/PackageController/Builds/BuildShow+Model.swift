extension BuildShow {

    struct Model {
        var logs: String
        var packageName: String
        var repositoryName: String
        var repositoryOwner: String

        init?(build: App.Build) {
            guard
                let packageName = build.version.package.name(),
                let repository = build.version.package.repository,
                let repositoryOwner = repository.owner,
                let repositoryName = repository.name
            else { return nil }
            self.init(logs: build.logs ?? "",
                      packageName: packageName,
                      repositoryOwner: repositoryOwner,
                      repositoryName: repositoryName)
        }

        internal init(logs: String,
                      packageName: String,
                      repositoryOwner: String,
                      repositoryName: String) {
            self.logs = logs
            self.packageName = packageName
            self.repositoryOwner = repositoryOwner
            self.repositoryName = repositoryName
        }
    }

}


extension BuildShow.Model {
    var buildsURL: String {
        SiteURL.package(.value(repositoryOwner), .value(repositoryName), .builds).relativeURL()
    }

    var packageURL: String {
        SiteURL.package(.value(repositoryOwner), .value(repositoryName), .none).relativeURL()
    }
}
