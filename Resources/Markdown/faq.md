---
page-title: FAQ
---
## Frequently Asked Questions

* [What is the Swift Package Index?](#what-is-the-spi)
* [What is the Swift Package Manager?](#what-is-the-spm)
* [Who built the Swift Package Index?](#creators)
* [What happened to the SwiftPM Library?](#swiftpm-library)
* [How does the Swift Package Index work?](#how-does-it-work)
* [What about the GitHub Package Registry?](#package-registry)
* [How do I define Language and Platform information?](#language-and-platforms)
* [Why do some packages show a red license lozenge?](#incompatible-license)
* [Can I contribute?](#contributing)

---

<h3 id="what-is-the-spi">What is the Swift Package Index?</h3>

The Swift Package Index is a search engine for packages that support the Swift Package Manager.

But this site isn't simply a search tool. Choosing the right dependencies is about more than just finding code that does what you need. Are the libraries you're choosing well maintained? How long have they been in development? Are they well tested? Picking high-quality packages is hard, and **the Swift Package Index helps you make better decisions about your dependencies**.

---

<h3 id="what-is-the-spm">What is the Swift Package Manager?</h3>

The [Swift Package Manager](https://swift.org/package-manager/) is a tool built by Apple as part of [the Swift project](https://swift.org) for integrating libraries and frameworks into your Swift apps. It launched in 2015 and gained integration with Xcode 11 in 2019.

To find out more about the Swift Package Manager, there's [documentation on the Apple developer site](https://developer.apple.com/documentation/xcode/adding_package_dependencies_to_your_app).

---

<h3 id="creators">Who built the Swift Package Index?</h3>

Thanks for asking! It was built by [Dave Verwer](https://daveverwer.com) and [Sven A. Schmidt](https://finestructure.co/). You can also see a [full list of contributors](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/graphs/contributors).

---

<h3 id="swiftpm-library">What happened to the SwiftPM Library?</h3>

This site is a spiritual successor and replacement for [the SwiftPM Library](/images/swiftpm-library.png). It has been re-implemented from scratch in Swift using Vapor and has had a name change at the same time. We learned many valuable lessons from the original implementation, and the Swift Package Index is the future of Swift package search.

---

<h3 id="how-does-it-work">How does the Swift Package Index work?</h3>

The data in this index originates from [this master list of repositories](https://github.com/daveverwer/SwiftPMLibrary/blob/master/packages.json). When someone adds a repository to the master list, this site immediately makes a full clone of the package source. Metadata is extracted from the source code and local git history, as well as from the hosted repository on GitHub.

Packages are also polled for changes every few hours, so the information you see in the index always reflects the latest package releases, without any action required from the package author.

---

<h3 id="package-registry">What about the GitHub Package Registry?</h3>

We’re excited to see the GitHub Package Registry gain support for the Swift packages. There’s [a proposal under discussion](https://forums.swift.org/t/swift-package-registry-service/37219) for the Swift Package Manager support to support package registries formally, but a package registry is not a package search engine like this site is. If the Swift project accepts the proposal, this site will support and index the GitHub Package Registry, and any other significant implementation of a package registry as they become available.

---

<h3 id="language-and-platforms">How do I define Language and Platform information?</h3>

The more metadata the Swift Package Index knows about your package, the better we can present it to people looking for packages. However, we need package authors to inform us of what platforms and languages their packages require, and support.

Are you a package author? Does your package listing currently look like this?

<picture>
  <source srcset="/images/language-and-platforms-no-metadata~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/language-and-platforms-no-metadata~light.png" alt="Missing language and platform metadata">
</picture>

Read on to learn how to specify this information in your `Package.swift` manifest.

#### Providing Swift language version metadata

Define the versions of Swift that your package is compatible with by setting the [`swiftLanguageVersions`](https://developer.apple.com/documentation/swift_packages/package/3197887-swiftlanguageversions) property in your package manifest, `Package.swift`. This property is an array of [`SwiftVersion`](https://developer.apple.com/documentation/swift_packages/swiftversion) enums:

```swift
swiftLanguageVersions: [.v4, .v4_2, .v5]
```

`SwiftVersion` does not define *all* versions of Swift, only significant versions. For example, if your package supports Swift 5, 5.1, and 5.2 then your `swiftLanguageVersions` should look like this:

```swift
swiftLanguageVersions: [.v5]
```

Once you push an updated `Package.swift` to your project's hosted repository, the Swift Package Index will re-scan and pick up your new metadata within a few hours. After the update, your listing will look something like this:

<picture>
  <source srcset="/images/language-and-platforms-language-only~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/language-and-platforms-language-only~light.png" alt="Swift language metadata">
</picture>

**Note:** Be careful not to mix up `swiftLanguageVersions` with the `swift-tools-version` comment at the top of your `Package.swift` file. `swiftLanguageVersions` defines the version(s) of Swift your package supports, and `swift-tools-version` determines what version of Swift is required to parse the `Package.swift` file. The Swift Package Index *only* parses the `swiftLanguageVersions` metadata.

#### Providing platform compatibility metadata

Define the Apple platforms (iOS, macOS, watchOS, or tvOS) that your package is compatible with by setting the [`platforms`](https://developer.apple.com/documentation/swift_packages/package/3197886-platforms) property in your package manifest. This property is an array of [`SupportedPlatform`](https://developer.apple.com/documentation/swift_packages/supportedplatform) enums:

```swift
platforms: [.macOS(.v10_12),
            .iOS(.v10),
            .tvOS(.v10),
            .watchOS(.v3)]
```

Push an updated `Package.swift` and the Swift Package Index will automatically update within a few hours. Once it updates, your listing will look like this:

<picture>
  <source srcset="/images/language-and-platforms-full-metadata~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/language-and-platforms-full-metadata~light.png" alt="Swift language and platform metadata">
</picture>

**Note:** Unfortunately, `Package.swift` does not currently support platform metadata to indicate whether a package is compatible with Linux. If this ever changes, the Swift Package Index will support it.

---

<h3 id="incompatible-license">Why do some packages show a red license lozenge?</h3>

If a package's license shows in a red lozenge rather than a green one, it is for one of two reasons:

1. We're unable to detect software license the package uses.
2. The license chosen by the package authors is incompatible with the terms and conditions of the App Store.

#### Unknown License

If the package license is showing as "Unknown License", it means the code is either unlicensed, or we have been unable to detect the license. We get this information directly from GitHub, so if you are the package author and would like to fix this, please [see GitHub's documentation](https://help.github.com/en/github/creating-cloning-and-archiving-repositories/licensing-a-repository#detecting-a-license). The Swift Package Index will update licenses a few hours after GitHub recognises a valid license.

For more information, read [this great blog post](https://expressionengine.com/blog/the-truth-about-the-risks-of-unlicensed-software) on the significant risks of using unlicensed code.

#### Incompatible license

If the package license shows in an orange lozenge but does *not* say "Unknown License", then the package is using a license which is incompatible with the terms and conditions of the App Store, such as any version of a GPL license.

Using code licensed under an license incompatible with the App Store presents a significant legal risk.

---

<h3 id="contributing">Can I contribute?</h3>

Absolutely. The Swift Package Index is [open-source](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server), and we’d love it if you wanted to help us make it better.

If you spot a bug or want to make a small fix to the site, pull requests are welcome. If you have a feature request, a good first step is to look through the [list of open issues](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues) and see if it’s already under discussion. If it’s not, please [open a new issue](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/new/choose).

For feature development, we prefer to receive issues rather than completed pull requests. After a discussion, if the enhancement you’re proposing fits well with our vision for the index, we’ll encourage you to take it to a pull request.
