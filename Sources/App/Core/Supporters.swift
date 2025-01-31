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
    static let primary: Corporate = .init(name: "Apple",
                                          logo: .init(lightModeUrl: "/images/sponsors/apple.svg",
                                                      darkModeUrl: "/images/sponsors/apple~dark.svg",
                                                      width: 100, height: 123),
                                          url: "http://apple.com")

    nonisolated(unsafe) static var corporate: [Corporate] = [
        .init(name: "Emerge Tools",
              logo: .init(lightModeUrl: "/images/sponsors/emerge.png",
                          darkModeUrl: "/images/sponsors/emerge~dark.png"),
              url: "https://www.emergetools.com/?utm_source=spi2&utm_medium=sponsor&utm_campaign=emerge",
              advertisingCopy: "Join the future of mobile development. Trusted by top companies like Duolingo, Square, DoorDash & more…"),
        .init(name: "RevenueCat",
              logo: .init(lightModeUrl: "/images/sponsors/revenuecat.png",
                          darkModeUrl: "/images/sponsors/revenuecat~dark.png"),
              url: "https://www.revenuecat.com/?utm_medium=sponsored&utm_source=swift_package_index&utm_campaign=general_sponsorship&utm_content=banner%20ad",
              advertisingCopy: "The world’s best apps use RevenueCat to power in-app purchases, manage customer data, and grow revenue."),
    ]

    nonisolated(unsafe) static var infrastructure: [Corporate] = [
        .init(name: "MacStadium",
              logo: .init(lightModeUrl: "/images/sponsors/macstadium.png",
                          darkModeUrl: "/images/sponsors/macstadium~dark.png"),
              url: "https://www.macstadium.com/?utm_medium=referral&utm_source=partner-post&utm_campaign=FOSS%20Program_Swift%20Package%20Index"),
        .init(name: "Microsoft Azure",
              logo: .init(lightModeUrl: "/images/sponsors/microsoft.png",
                          darkModeUrl: "/images/sponsors/microsoft~dark.png"),
              url: "https://azure.microsoft.com"),
        .init(name: "Amazon Web Services (AWS)",
              logo: .init(lightModeUrl: "/images/sponsors/aws.png",
                          darkModeUrl: "/images/sponsors/aws~dark.png"),
              url: "https://aws.amazon.com/"),
        .init(name: "Cloudflare",
              logo: .init(lightModeUrl: "/images/sponsors/cloudflare.png",
                          darkModeUrl: "/images/sponsors/cloudflare~dark.png"),
              url: "https://cloudflare.com/")
    ]

    nonisolated(unsafe) static var community: [Community] = .gitHubSponsors

    struct Corporate {
        var name: String
        var logo: Logo
        var url: String
        var advertisingCopy: String?

        struct Logo {
            var lightModeUrl: String
            var darkModeUrl: String
            var width: Int = 300
            var height: Int = 100
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
