//
//  File.swift
//  
//
//  Created by Sven A. Schmidt on 26/04/2020.
//

import Foundation


struct AppEnvironment {
    var githubToken: () -> String?
}

extension AppEnvironment {
    static let live: Self = .init(
        githubToken: { ProcessInfo.processInfo.environment["GITHUB_TOKEN"] }
    )
}


#if DEBUG
var Current: AppEnvironment = .live
#else
let Current: AppEnvironment = .live
#endif
