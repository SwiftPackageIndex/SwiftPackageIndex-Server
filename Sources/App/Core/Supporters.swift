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
        .init(name: "TelemetryDeck",
              logo: .init(lightModeUrl: "/images/sponsors/telemetrydeck.png",
                          darkModeUrl: "/images/sponsors/telemetrydeck~dark.png"),
              url: "http://telemetrydeck.com/?utm_source=swiftpackageindex&utm_campaign=swiftpackageindex_0723",
              advertisingCopy: "Get light-weight, anonymized, privacy-focused usage data analytics for your app."),
        .init(name: "Point-Free",
              logo: .init(lightModeUrl: "/images/sponsors/point-free.png",
                          darkModeUrl: "/images/sponsors/point-free~dark.png"),
              url: "https://www.pointfree.co/?ref=spi-promo",
              advertisingCopy: "Upgrade your Swift programming skills with advanced, quality videos on architecture, testing, and more.")
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
