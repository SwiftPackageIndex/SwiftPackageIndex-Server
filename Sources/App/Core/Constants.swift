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
    
    static let latestMajorSwiftVersion = 5
    
    static let packageListUri = URI(string: "https://raw.githubusercontent.com/SwiftPackageIndex/PackageList/main/packages.json")
    
    // NB: the underlying materialised views also have a limit, this is just an additional
    // limit to ensure we don't display we don't spill too many rows onto the home page
    static let recentPackagesLimit = 7
    static let recentReleasesLimit = 7
    
    static let reIngestionDeadtime: TimeInterval = 90 * 60  // in seconds
    
    static let rssFeedMaxItemCount = 100
    static let rssTTL = 60  // minutes
    
    static let searchLimit = 20
    static let searchLimitLeeway = 5

    // build system settings
    static let trimBuildsGracePeriod = 4  // hours
    static let branchBuildDeadTime = 24 // hours
    static let branchVersionRefreshDelay = 24.hours
}
