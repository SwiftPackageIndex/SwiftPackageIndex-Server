@testable import App

import Foundation


extension PackageShow.PackageSchema {
    static var mock: PackageShow.PackageSchema {
        .init(
            repositoryOwner: "Owner",
            repositoryName: "Name",
            organisationName: "MegaOwner Corporation",
            summary: "This is an amazing package.",
            licenseUrl: "https://github.com/Alamofire/Alamofire/blob/master/LICENSE",
            version: "5.2.0",
            repositoryUrl: "https://github.com/Alamofire/Alamofire",
            dateCreated: .init(timeIntervalSince1970: 0),
            dateModified: .init(timeIntervalSinceReferenceDate: 0),
            keywords: ["foo", "bar", "baz"]
        )
    }
}
