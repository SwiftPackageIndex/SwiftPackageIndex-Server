extension Search {
    enum Result: Codable, Equatable {
        case keyword(KeywordResult)
        case package(PackageResult)

        init?(_ record: DBRecord) {
            switch (record.matchType, record.keyword) {
                case let (.keyword, .some(kw)):
                    self = .keyword(.init(keyword: kw))
                case (.keyword, .none):
                    return nil
                case (.package, _):
                    self = .package(
                        .init(packageId: record.packageId,
                              packageName: record.packageName,
                              packageURL: record.packageURL,
                              repositoryName: record.repositoryName,
                              repositoryOwner: record.repositoryOwner,
                              summary: record.summary?.replaceShorthandEmojis())
                    )
            }
        }
    }

    struct KeywordResult: Codable, Equatable {
        var keyword: String
    }

    struct PackageResult: Codable, Equatable {
        var packageId: Package.Id?
        var packageName: String?
        var packageURL: String?
        var repositoryName: String?
        var repositoryOwner: String?
        var summary: String?
    }
}


extension Search.Result {
    var packageId: Package.Id? {
        switch self {
            case .keyword:
                return nil
            case let .package(res):
                return res.packageId
        }
    }

    var packageName: String? {
        switch self {
            case .keyword:
                return nil
            case let .package(res):
                return res.packageName
        }
    }

    var packageURL: String? {
        switch self {
            case .keyword:
                return nil
            case let .package(res):
                return res.packageURL
        }
    }

    var repositoryName: String? {
        switch self {
            case .keyword:
                return nil
            case let .package(res):
                return res.repositoryName
        }
    }

    var repositoryOwner: String? {
        switch self {
            case .keyword:
                return nil
            case let .package(res):
                return res.repositoryOwner
        }
    }

    var summary: String? {
        switch self {
            case .keyword:
                return nil
            case let .package(res):
                return res.summary
        }
    }
}
