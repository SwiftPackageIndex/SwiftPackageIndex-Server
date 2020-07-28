extension BuildShow {

    struct Model {
        var logs: String
        var repositoryName: String
        var repositoryOwner: String

        init?(build: App.Build) {
            guard
                let repository = build.version.package.repository,
                let repositoryOwner = repository.owner,
                let repositoryName = repository.name
            else { return nil }
            self.init(logs: build.logs ?? "",
                      repositoryOwner: repositoryOwner,
                      repositoryName: repositoryName)
        }

        internal init(logs: String,
                      repositoryOwner: String,
                      repositoryName: String) {
            self.logs = logs
            self.repositoryOwner = repositoryOwner
            self.repositoryName = repositoryName
        }
    }

}


extension BuildShow.Model {
    var buildsURL: String {
        SiteURL.package(.value(repositoryOwner), .value(repositoryName), .builds).relativeURL()
    }
}
