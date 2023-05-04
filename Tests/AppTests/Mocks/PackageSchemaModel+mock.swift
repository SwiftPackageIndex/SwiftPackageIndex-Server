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

@testable import App

import Foundation


extension API.PackageController.GetRoute.PackageSchema {
    static var mock: Self {
        .init(
            repositoryOwner: "Owner",
            repositoryName: "Name",
            organisationName: "MegaOwner Corporation",
            summary: "This is an amazing package.",
            licenseUrl: "https://github.com/Alamofire/Alamofire/blob/master/LICENSE",
            version: "5.2.0",
            repositoryUrl: "https://github.com/Alamofire/Alamofire",
            datePublished: .init(timeIntervalSince1970: 0),
            dateModified: .init(timeIntervalSinceReferenceDate: 0),
            keywords: ["foo", "bar", "baz"]
        )
    }
}
