//
//  File.swift
//  
//
//  Created by Sven A. Schmidt on 26/04/2020.
//

import Vapor


struct AppEnvironment {
    var fetchMasterPackageList: (_ client: Client) throws -> EventLoopFuture<[URL]>
    var fetchRepository: (_ client: Client, _ package: Package) throws -> EventLoopFuture<Github.Metadata>
    var githubToken: () -> String?
}

extension AppEnvironment {
    static let live: Self = .init(
        fetchMasterPackageList: liveFetchMasterPackageList,
        fetchRepository: Github.fetchRepository(client:package:),
        githubToken: { ProcessInfo.processInfo.environment["GITHUB_TOKEN"] }
    )
}


#if DEBUG
var Current: AppEnvironment = .e2eTesting
#else
let Current: AppEnvironment = .live
#endif
