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

enum Supporters {
    static var primary: Corporate = .init(name: "Apple",
                                          logo: .init(lightModeUrl: "/images/sponsors/apple.svg",
                                                      darkModeUrl: "/images/sponsors/apple~dark.svg",
                                                      width: 100, height: 123),
                                          url: "http://apple.com")

    static var corporate: [Corporate] = [
        .init(name: "Stream",
              logo: .init(lightModeUrl: "/images/sponsors/stream.png",
                          darkModeUrl: "/images/sponsors/stream~dark.png"),
              url: "https://getstream.io/chat/sdk/swiftui/?utm_source=SwiftPackageIndex&utm_medium=Github_Repo_Content_Ad&utm_content=Developer&utm_campaign=SwiftPackageIndex_Apr2022_SwiftUIChat",
              advertisingCopy: "Build reliable, real-time, in-app chat and messaging in less time."),
        .init(name: "Emerge Tools",
              logo: .init(lightModeUrl: "/images/sponsors/emerge.png",
                          darkModeUrl: "/images/sponsors/emerge~dark.png"),
              url: "https://www.emergetools.com/?utm_source=spi&utm_medium=sponsor&utm_campaign=emerge",
              advertisingCopy: "Monitor app size, improve startup time, and prevent performance regressions.")
    ]

    static var infrastructure: [Corporate] = [
        .init(name: "MacStadium",
              logo: .init(lightModeUrl: "/images/sponsors/macstadium.png",
                          darkModeUrl: "/images/sponsors/macstadium~dark.png"),
              url: "https://macstadium.com"),
        .init(name: "Microsoft Azure",
              logo: .init(lightModeUrl: "/images/sponsors/microsoft.png",
                          darkModeUrl: "/images/sponsors/microsoft~dark.png"),
              url: "https://azure.microsoft.com")
    ]

    static var community: [Community] = .gitHubSponsors

    struct Corporate {
        var name: String
        var logo: Logo
        var url: String
        var advertisingCopy: String?

        struct Logo {
            var lightModeUrl: String
            var darkModeUrl: String
            var width: Int = 300
            var height: Int = 75
        }
    }

    struct Community {
        let login: String
        let name: String?
        let avatarUrl: String

        var gitHubUrl: String {
            "https://github.com/\(login)"
        }
    }
}
