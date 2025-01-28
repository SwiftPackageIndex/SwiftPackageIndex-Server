// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Vapor


enum Constants {
    static let defaultAllowBuildTriggering = true
    static let defaultAllowSocialPosts = true
    static let defaultGitlabPipelineLimit = 200
    static let defaultHideStagingBanner = false

    static let githubComPrefix = "https://github.com/"
    static let gitSuffix = ".git"

    static let packageListUri = URI(string: "https://raw.githubusercontent.com/SwiftPackageIndex/PackageList/main/packages.json")
    static let packageDenyListUri = URI(string: "https://raw.githubusercontent.com/SwiftPackageIndex/PackageList/main/denylist.json")
    static let customCollectionsUri = URI(string: "https://raw.githubusercontent.com/SwiftPackageIndex/PackageList/main/custom-package-collections.json")

    static let maxCustomPackageCollectionSize = 50

    // NB: the underlying materialised views also have a limit, this is just an additional
    // limit to ensure we don't spill too many rows onto the home page
    static let recentPackagesLimit = 7
    static let recentReleasesLimit = 7

    static let reIngestionDeadtime: TimeInterval = .minutes(90)

    static let rssFeedMaxItemCount = 500
    static let rssTTL: TimeInterval = .minutes(60)

    // analyzer settings
    static let gitCheckoutMaxAge: TimeInterval = .days(30)

    // build system settings
    static let trimBuildsGracePeriod: TimeInterval = .hours(4)
    static let branchVersionRefreshDelay: TimeInterval = .hours(24)

    // package
    static let maxKeywordPackageCollectionCount = 300
}
