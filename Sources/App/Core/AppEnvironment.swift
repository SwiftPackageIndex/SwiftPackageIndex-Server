//
//  File.swift
//  
//
//  Created by Sven A. Schmidt on 26/04/2020.
//

import Vapor


struct AppEnvironment {
    var fetchMasterPackageList: (_ client: Client) throws -> EventLoopFuture<[URL]>
    var githubToken: () -> String?
}

extension AppEnvironment {
    static let live: Self = .init(
        fetchMasterPackageList: liveFetchMasterPackageList,
        githubToken: { ProcessInfo.processInfo.environment["GITHUB_TOKEN"] }
    )
}

extension AppEnvironment {
    static let mock: Self = .init(
        fetchMasterPackageList: { _ in
            let eventLoop = EmbeddedEventLoop()
            return eventLoop.makeSucceededFuture([
                URL(string: "https://github.com/finestructure/Gala")!,
                URL(string: "https://github.com/finestructure/SwiftPMLibrary-Server")!,
            ])
        },
        githubToken: { ProcessInfo.processInfo.environment["GITHUB_TOKEN"] }
    )
}


#if DEBUG
var Current: AppEnvironment = .mock
#else
let Current: AppEnvironment = .live
#endif
