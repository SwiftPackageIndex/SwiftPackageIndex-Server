import Foundation

import VaporToOpenAPI


// MARK: - External types

extension Date: WithExample {
    public static var example: Self { .init(rfc1123: "Sat, 25 Apr 2020 10:55:00 UTC")! }
}


// MARK: - Internal types

extension Badge: WithExample {
    static var example: Self { .init(significantBuilds: .example, badgeType: .platforms)}
}


extension API.PackageController.Query: WithExample {
    static var example: Self { .init(type: .platforms) }
}


extension API.SearchController.Query: WithExample {
    static var example: Self { .init(query: "LinkedList") }
}


extension Search.Result: WithExample {
    static var example: Self {
        .package(
            .init(packageId: .example,
                  packageName: "LinkedList",
                  packageURL: "https://github.com/mona/LinkedList.git",
                  repositoryName: "LinkedList",
                  repositoryOwner: "mona",
                  stars: 123,
                  lastActivityAt: .example,
                  summary: "An example package",
                  keywords: [],
                  hasDocs: true)!
        )
    }
}


extension Search.Response: WithExample {
    static var example: Self {
        .init(hasMoreResults: false,
              searchTerm: "LinkedList",
              searchFilters: [.example],
              results: [.example])
    }
}


extension SearchFilter.ViewModel: WithExample {
    static var example: Self {
        .init(key: "author", operator: "is", value: "mona")
    }
}


extension SignificantBuilds: WithExample {
    static var example: Self {
        .init(buildInfo: [
            (.v5_8, Build.Platform.ios, .ok)
        ])
    }
}


// MARK: - Package collection types

import PackageCollectionsModel


extension API.PostPackageCollectionOwnerDTO: WithExample {
    static var example: Self {
        .init(owner: "mona")
    }
}

extension API.PostPackageCollectionPackageUrlsDTO: WithExample {
    static var example: Self {
        .init(packageUrls: ["https://github.com/mona/LinkedList.git"])
    }
}

extension PackageCollectionModel.V1.Collection: WithExample {
    public static var example: Self {
        .init(name: "Packages by mona",
              overview: "A collection of packages authored by mona from the Swift Package Index",
              keywords: nil, packages: [
                .init(url: URL(string: "https://github.com/mona/LinkedList.git")!,
                      summary: "An example package",
                      keywords: nil,
                      versions: [],
                      readmeURL: URL(string: "https://github.com/mona/LinkedList/blob/main/README.md")!,
                      license: .init(name: "MIT",
                                     url: URL(string: "https://github.com/mona/LinkedList/blob/main/LICENSE")!))
              ],
              formatVersion: .v1_0,
              revision: nil,
              generatedBy: .init(name: "mona"))
    }
}

extension PackageCollectionModel.V1.Signature.Certificate: WithExample {
    public static var example: Self {
        .init(subject: .init(userID: "V676TFACYJ",
                             commonName: "Swift Package Collection: SPI Operations Limited",
                             organizationalUnit: "V676TFACYJ",
                             organization: "SPI Operations Limited"),
              issuer: .init(userID: nil,
                            commonName: "Apple Worldwide Developer Relations Certification Authority",
                            organizationalUnit: "G3",
                            organization: "Apple Inc."))
    }
}

extension PackageCollectionModel.V1.Signature: WithExample {
    public static var example: Self {
        .init(signature: "ewogICJhbGciIDogIlJ...<snip>...WD1pXXPrkvVJlv4w", certificate: .example)
    }
}

extension SignedCollection: WithExample {
    public static var example: Self {
        .init(collection: .example, signature: .example)
    }
}


// MARK: - Build/doc reporting types

extension API.PostBuildReportDTO: WithExample {
    static var example: Self {
        .init(buildId: .example,
              platform: .ios,
              status: .ok,
              swiftVersion: .v5_8)
    }
}

extension API.PostDocReportDTO: WithExample {
    static var example: Self {
        .init(docArchives: [.init(name: "linkedlist", title: "LinkedList")],
              error: nil,
              fileCount: 2639,
              logUrl: "https://us-east-2.console.aws.amazon.com/logs/123456678",
              mbSize: 23,
              status: .ok)
    }
}
