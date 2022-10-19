---
page-title: FAQ
description: Frequently Asked Questions about the Swift Package Index
---

## Frequently Asked Questions

- [What is the Swift Package Index?](#what-is-the-spi)
- [What is the Swift Package Manager?](#what-is-the-spm)
- [Who built the Swift Package Index?](#creators)
- [Can I support the Swift Package Index?](#support)
- [What happened to the SwiftPM Library?](#swiftpm-library)
- [How does the Swift Package Index work?](#how-does-it-work)
- [What about the GitHub Package Registry?](#package-registry)
- [How is the Swift language and platform support calculated?](#language-and-platforms)
- [Why are certain licenses highlighted?](#licenses)
- [Can I contribute to the Swift Package Index?](#contributing)
- [Is there an API?](#api)
- [Why are package versions missing?](#missing-versions)
- [What is the SPI-Playgrounds app?](#spi-playgrounds-app)
- [How can I filter search results?](#search-filters)

---

<h3 id="what-is-the-spi">What is the Swift Package Index?</h3>

The Swift Package Index is a search engine for packages that support the Swift Package Manager.

But this site isn't simply a search tool. Choosing the right dependencies is about more than just finding code that does what you need. Are the libraries you're choosing well maintained? How long have they been in development? Are they well tested? Picking high-quality packages is hard, and **the Swift Package Index helps you make better decisions about your dependencies**.

---

<h3 id="what-is-the-spm">What is the Swift Package Manager?</h3>

The [Swift Package Manager](https://swift.org/package-manager/) is a tool built by Apple as part of [the Swift project](https://swift.org) for integrating libraries and frameworks into your Swift apps. It launched in 2015 and gained integration with Xcode 11 in 2019.

To find out more about the Swift Package Manager, there's [documentation on the Apple developer site](https://developer.apple.com/documentation/swift_packages/adding_package_dependencies_to_your_app).

---

<h3 id="creators">Who built the Swift Package Index?</h3>

Thanks for asking! It was built by [Dave Verwer](https://daveverwer.com) and [Sven A. Schmidt](https://finestructure.co/). You can also see a [full list of contributors](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/graphs/contributors).

---

<h3 id="support">Can I support the Swift Package Index?</h3>

We'd love to have your support. Thank you! You can read more about [how we are funding this project](https://blog.swiftpackageindex.com/posts/funding-the-future-of-the-swift-package-index/) and [support it via GitHub sponsors](https://github.com/sponsors/SwiftPackageIndex).

---

<h3 id="swiftpm-library">What happened to the SwiftPM Library?</h3>

This site is a spiritual successor and replacement for [the SwiftPM Library](/images/screenshots/swiftpm-library.png). It has been re-implemented from scratch in Swift using Vapor and has had a name change at the same time. We learned many valuable lessons from the original implementation, and the Swift Package Index is the future of Swift package search.

---

<h3 id="how-does-it-work">How does the Swift Package Index work?</h3>

The data in this index originates from [this list of repositories](https://github.com/SwiftPackageIndex/PackageList/blob/main/packages.json). When someone adds a repository to the package list, this site immediately makes a full clone of the package source. Metadata is extracted from the source code and local git history, as well as from the hosted repository on GitHub.

Packages are also polled for changes every few hours, so the information you see in the index always reflects the latest package releases, without any action required from the package author.

---

<h3 id="package-registry">What about the GitHub Package Registry?</h3>

We’re excited to see the GitHub Package Registry gain support for the Swift packages. There’s [a proposal under discussion](https://forums.swift.org/t/swift-package-registry-service/37219) for the Swift Package Manager support to support package registries formally, but a package registry is not a package search engine like this site is. If the Swift project accepts the proposal, this site will support and index the GitHub Package Registry, and any other significant implementation of a package registry as they become available.

---

<h3 id="language-and-platforms">How is the Swift language and platform support calculated?</h3>

The Swift Package Index includes build information which is not able to be derived from the package manifest. Including full coverage of both Swift version compatibility, and platform compatibility, including Linux!

<picture class="shadow">
  <source srcset="/images/screenshots/languages-and-platforms~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/screenshots/languages-and-platforms~light.png" alt="Language and Platform information on a package page">
</picture>

To determine what versions of Swift a package supports, and what platforms it is compatible with, the Swift Package Index runs real-world builds using several Swift compilers targeting several different platforms. You can learn more about how we do this in the [Swift Package Index Build System FAQ](/docs/builds).

---

<h3 id="licenses">Why are certain licenses highlighted?</h3>

If a package's license shows with an orange or red exclamation mark icon, it is for one of three reasons:

1. The package has no license.
2. We have been unable to automatically detect the software license used by the package.
3. The license chosen by the package authors may be incompatible with the App Store.

#### No License

If the package license is showing as "No License" with a red exclamation icon, we could not find _any_ license information in the package repository.

Using a package that does not have a license presents a significant legal risk. Unlicensed code is not open-source, and the original author reserves all rights by default. For more information, read [this great blog post](https://expressionengine.com/blog/the-truth-about-the-risks-of-unlicensed-software) on using unlicensed code.

If you are the package author, you can fix this by adding a `LICENSE` file with an open-source license in your package's repository. The Swift Package Index will update license metadata a few hours after you add the license.

#### Unknown License

If the package license is showing as "Unknown License" with an orange exclamation icon, we have been unable to automatically detect a license in the package repository.

There could be one of several reasons automatic detection failed. The package may use a commercial or closed-source license, or it could be that GitHub's license detection algorithm has failed. Before using a package with an unknown license, you should check the package repository for a `LICENSE` file and ensure you understand the terms that the package author has defined.

If you are the author of a package showing with an unknown license and believe it should show a valid open-source license, please [see GitHub's documentation](https://docs.github.com/en/github/creating-cloning-and-archiving-repositories/licensing-a-repository#detecting-a-license). The Swift Package Index will update licenses a few hours after GitHub recognises a valid license.

#### Incompatible license

If the package license shows with an orange exclamation icon but does _not_ say "No License" or "Unknown License", then the package is using a license which may be incompatible with how the App Store works, such as a GPL-style license. If you are considering shipping software that includes a package licensed with one of these licenses to the App Store, you should be aware that using code licensed under one of these licences may present a legal risk.

---

<h3 id="contributing">Can I contribute to the Swift Package Index?</h3>

Absolutely. The Swift Package Index is [open-source](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server), and we’d love it if you wanted to help us make it better. Please see the [guide to contributing in our README](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/blob/main/README.md#contributing) for more information.

All participation in this project, whether contributing code, communicating in discussions or issues, or pull requests, is subject to our code of conduct. Please read the [Code of Conduct](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/blob/main/CODE_OF_CONDUCT.md) before contributing.

---

<h3 id="api">Is there an API?</h3>

Not right now. The Swift Package Index is in a period of rapid development right now, and we'd like the flexibility to change things around at this stage in the project's life. It's on the list for the future though!

---

<h3 id="missing-versions">Why are package versions missing?</h3>

Package releases must use git tags that are _fully qualified_ [semantic versions](https://semver.org). For example, `2.6.0` is a valid semantic version number, and `2.6` is not.

A good way to check what the latest semantic version release of a package is is to add it to a project in Xcode. By default, Xcode will show the latest semantic version when adding the package to a project. The number you see on this site should match the version Xcode shows when adding the package. If you see something different, please [raise an issue](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/new/choose)!

<picture class="shadow">
  <source srcset="/images/screenshots/add-package-in-xcode~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/screenshots/add-package-in-xcode~light.png" alt="Adding a package in Xcode">
</picture>

---

<h3 id="spi-playgrounds-app">What is the SPI-Playgrounds app?</h3>

Have you ever wanted to try out a package in a Swift playground before you decide to use it? Click “Try in a Playground” from any package page and have the Swift Package Index Playgrounds app create a playground with the package automatically imported, ready for testing and experimentation.

If you don't have the SPI-Playgrounds app installed, you can [download it for macOS here](/try-in-a-playground).

---

<h3 id="search-filters">How can I filter search results?</h3>

You can narrow package search results with a search syntax that filters based on package metadata. For example, you could search for packages that [match "networking" and have more than 500 stars](https://swiftpackageindex.com/search?query=networking+stars%3A%3E500).

The following package metadata fields are supported:

- `author` (Author): The owner of the package's repository.
- `last_activity` (Date): The most recent maintenance activity on the package repository. Any commit to the default branch or merging/closing an issue or pull request counts as a maintenance activity.
- `last_commit` (Date): The date of the last commit to the package repository.
- `license` (License): The package's license.
- `keyword` (Keyword): Filter on matching package keywords.
- `platform` (Platform(s)): Filter on one or more compatible platforms (iOS, macOS, watchOS, tvOS, or Linux).
- `stars` (Number): The number of stars the package has.
- `product` (Product): The type of product the package should contain (executable, library, plugin).

Use `>`, `>=`, `<` and `<=` to filter for values greater than, greater than or equal to, less than, and less than or equal to another value. All filters are combined with an AND operator.

For example, a query of [`http stars:>500 platform:ios,linux`](https://swiftpackageindex.com/search?query=http+stars%3A%3E500+platform%3Aios%2Clinux) shows packages matching the word "http" that have more than 500 stars and are compatible with both iOS and Linux platforms.

#### Querying Number values

You can filter on numeric values with any integer and the standard `>`, `>=`, `<` and `<=` operators.

#### Querying Date values

Specify all dates using [ISO8601](https://en.wikipedia.org/wiki/ISO_8601) format, which is `YYYY-MM-DD` (year-month-day). You can filter on dates with the standard `>`, `>=`, `<` and `<=` operators.

For example, a query of [`charts last_activity:>=2021-02-01`](https://swiftpackageindex.com/search?query=charts+last_activity%3A%3E2021-01-01) shows packages matching the word "charts" that have also received some maintenance activity since the start of February 2021.

#### Querying License values

You can search for packages that have a license which is [compatible with the App Store](#licenses) by simply querying [`license:compatible`](https://swiftpackageindex.com/search?query=license%3Acompatible).

You can also specify a specific license you wish a package to have from one of the [built-in options](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/blob/main/Sources/App/Models/License.swift). For example, a query of [`license:lgpl-2.1`](https://swiftpackageindex.com/search?query=license%3Algpl-2.1) matches any package licensed under the LGPL 2.1.

#### Querying Author or Keyword values

You can search for packages created by a specific user or organisation by filtering on `author`. For example, a query of [`fluent author:vapor`](https://swiftpackageindex.com/search?query=fluent+author%3Avapor) matches any package containing the word "fluent" owned by the vapor organisation.

Similarly, you can search for packages that contain keywords with a `keyword` filter. For example, [`keyword:accessibility`](https://swiftpackageindex.com/search?query=keyword%3Aaccessibility) matches any package having the "accessibility" keyword.

#### Querying Platform values

You can search for packages that are compatible with a platform using a `platform` filter. Specify multiple platforms together with commas. For example, [`testing platform:ios,linux`](https://swiftpackageindex.com/search?query=testing+platform%3Aios%2Clinux) shows packages matching the word "layout" that are compatible with both iOS and Linux.

**Note:** Platform compatibility data comes from the [build system](/docs/builds) and is sourced from real-world build results.

#### Excluding results using filters

You can also exclude packages that match a filter by prefixing the filter value with an `!` character. For example, searching for [`license:!mit`](https://swiftpackageindex.com/search?query=license%3A%21mit) matches packages that are not licensed under the MIT license.
