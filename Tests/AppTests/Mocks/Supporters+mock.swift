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

extension Supporters {
    static func mock() {
        corporate = .mock
        community = .mock
    }
}

extension Array<Supporters.Corporate> {
    static var mock: Self = [
        .init(name: "Sample Sponsor", logo: .init(lightModeUrl: "/images/logo.svg", darkModeUrl: "/images/logo.svg"), url: "https://example.com/sponsored/link", advertisingCopy: "Sponsored links tell everyone about a thing that you can use to do another thing to do!")
    ]
}

extension Array<Supporters.Community> {
    static var mock: Self = [
        .init(login: "sponsor", name: "Community Sponsor", avatarUrl: "/images/logo.svg"),
        .init(login: "sponsor", name: "Community Sponsor", avatarUrl: "/images/logo.svg"),
        .init(login: "sponsor", name: "Community Sponsor", avatarUrl: "/images/logo.svg"),
        .init(login: "sponsor", name: "Community Sponsor", avatarUrl: "/images/logo.svg"),
        .init(login: "sponsor", name: "Community Sponsor", avatarUrl: "/images/logo.svg"),
        .init(login: "sponsor", name: "Community Sponsor", avatarUrl: "/images/logo.svg"),
        .init(login: "sponsor", name: "Community Sponsor", avatarUrl: "/images/logo.svg"),
        .init(login: "sponsor", name: "Community Sponsor", avatarUrl: "/images/logo.svg"),
        .init(login: "sponsor", name: "Community Sponsor", avatarUrl: "/images/logo.svg"),
        .init(login: "sponsor", name: "Community Sponsor", avatarUrl: "/images/logo.svg"),
        .init(login: "sponsor", name: "Community Sponsor", avatarUrl: "/images/logo.svg"),
        .init(login: "sponsor", name: "Community Sponsor", avatarUrl: "/images/logo.svg"),
        .init(login: "sponsor", name: "Community Sponsor", avatarUrl: "/images/logo.svg"),
        .init(login: "sponsor", name: "Community Sponsor", avatarUrl: "/images/logo.svg")
    ]
}
