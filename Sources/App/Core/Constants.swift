//
//  File.swift
//  
//
//  Created by Sven A. Schmidt on 26/04/2020.
//

import Vapor


enum Constants {
    static let defaultAllowBuildTriggering = true
    static let defaultAllowTwitterPosts = true
    static let defaultGitlabPipelineLimit = 200
    static let defaultHideStagingBanner = false
    
    static let githubComPrefix = "https://github.com/"
    static let gitSuffix = ".git"

    // FIXME: compute from SwiftVersion.allActive
    // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1136
    static let latestMajorSwiftVersion = 5

    static let packageListUri = URI(string: "https://raw.githubusercontent.com/SwiftPackageIndex/PackageList/main/packages.json")
    
    // NB: the underlying materialised views also have a limit, this is just an additional
    // limit to ensure we don't spill too many rows onto the home page
    static let recentPackagesLimit = 7
    static let recentReleasesLimit = 7
    
    static let reIngestionDeadtime: TimeInterval = .minutes(90)
    
    static let rssFeedMaxItemCount = 100
    static let rssTTL: TimeInterval = .minutes(60)
    
    static let searchPageSize = 20

    // analyzer settings
    static let gitCheckoutMaxAge: TimeInterval = .days(30)

    // build system settings
    static let trimBuildsGracePeriod: TimeInterval = .hours(4)
    static let branchVersionRefreshDelay: TimeInterval = .hours(24)
}
