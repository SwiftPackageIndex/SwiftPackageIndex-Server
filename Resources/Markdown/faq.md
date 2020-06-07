<h3 id="what-is-the-spi">What is the Swift Package Index?</h3>

The Swift Package Index is a search engine for packages that support the Swift Package Manager.

But it's about more than just indexing packages because choosing the right package is about more than just finding code that does what you need. Is it well maintained? What versions of Swift does it support? Is it well tested? How long has it been in development? **Picking high-quality packages is hard**, and *that's* where the Swift Package Index aims to be most useful.

---

<h3 id="what-is-the-spm">What is the Swift Package Manager?</h3>

The [Swift Package Manager](https://swift.org/package-manager/) is a fantastic tool built by Apple as part of [the Swift project](https://swift.org) for integrating libraries into your Swift apps. It launched in 2015 and gained integration with Xcode 11 in 2019.

---

<h3 id="swiftpm-library">What happened to the SwiftPM Library?</h3>

The Swift Package Index is a spiritual successor and replacement for [the SwiftPM Library](/images/swiftpm-library.png). It has been re-implemented from scratch in Swift using Vapor and has had a name change at the same time. We learned many valuable lessons from the original implementation, but the Swift Package Index is the future of Swift package search.

---

<h3 id="how-does-it-work">How does the Swift Package Index work?</h3>

The index originates from a [master list of SPM compatible repositories](https://github.com/daveverwer/SwiftPMLibrary/blob/master/packages.json). When someone adds a repository to the master list, the Swift Package Index immediately makes a full clone of the package source. Metadata is extracted both from source code and local git history, but also from GitHub. Packages are then polled for changes every few hours, so the information you see in the index always reflects the latest package releases, without any action from the package author.

---

<h3 id="package-registry">What about the GitHub Package Registry?</h3>

We’re excited to see the GitHub Package Registry get support for Swift packages. There’s [a proposal](https://forums.swift.org/t/swift-package-registry-service/37219) for Swift Package Manager support to support package registries formally, but that pitch is not for a package index or search engine. The Swift Package Index will support and index the GitHub Package Registry, and any other significant implementation of a package registry when they become available.

---

<h3 id="creators">Who built the Swift Package Index?</h3>

Thanks for asking! [Dave Verwer](https://daveverwer.com) and [Sven A. Schmidt](https://finestructure.co/) built it. You can also see a [full list of contributors](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/graphs/contributors).

---

<h3 id="language-and-platforms">How do I define Language and Platform information?</h3>

The more metadata the Swift Package Index knows about your package, the better we can present it to people looking for packages.

Does your package listing currently show this?

![Missing language and platform metadata](/images/language-and-platforms-no-metadata.png)

Two critical pieces of metadata are the **supported Swift language versions** and the **supported platforms** for your package.

#### Providing Swift language version metadata

Define the versions of Swift that your package is compatible with by setting the [`swiftLanguageVersions`](https://developer.apple.com/documentation/swift_packages/package/3197887-swiftlanguageversions) property in your package manifest, `Package.swift`. This property is an array of [`SwiftVersion`](https://developer.apple.com/documentation/swift_packages/swiftversion) enums:

```swift
swiftLanguageVersions: [.v4, .v4_2, .v5]
```

`SwiftVersion` does not define *all* versions of Swift, only versions that made source breaking changes. For example, if your package supports Swift 5, 5.1, and 5.2 then your `swiftLanguageVersions` should look like this:

```swift
swiftLanguageVersions: [.v5]
```

Once you add this key and push an updated `Package.swift`. The Swift Package Index will pick up your new metadata within a few hours. After the update, your listing will look something like this:

![Swift language metadata](/images/language-and-platforms-language-only.png)

**Note:** Be careful not to mix up `swiftLanguageVersions` with the `swift-tools-version` comment at the top of your `Package.swift` file. `swiftLanguageVersions` defines the version(s) of Swift your package supports, and `swift-tools-version` determines what version of Swift is required to parse your `Package.swift` file. The Swift Package Index *only* parses the `swiftLanguageVersions` metadata.

#### Providing platform compatibility metadata

Define the Apple platforms (iOS, macOS, watchOS, or tvOS) that your package is compatible with by setting the [`platforms`](https://developer.apple.com/documentation/swift_packages/package/3197886-platforms) property in your package manifest. This property is an array of [`SupportedPlatform`](https://developer.apple.com/documentation/swift_packages/supportedplatform) enums:

```swift
platforms: [.macOS(.v10_12),
            .iOS(.v10),
            .tvOS(.v10),
            .watchOS(.v3)]
```

Add or update this property and push an updated `Package.swift`.  The index will update within a few hours, and your listing will look something like this:

![Swift language and platform metadata](/images/language-and-platforms-full-metadata.png)

**Note:** Unfortunately, `Package.swift` does not currently support platform metadata that includes Linux compatibility. If this ever changes, the Swift Package Index will support it.

---

<h3 id="contributing">Can I contribute?</h3>

Absolutely. The Swift Package Index is open source, and we’d love it if you wanted to help make it better.

If you spot a bug or want to make a small fix to the site, pull requests are welcome. If you have a feature request, a good first step is to look through the [list of open issues](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues) and see if it’s already under discussion. If it’s not, please [open a new issue](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/new/choose).

We prefer to receive issues rather than completed pull requests for feature development. After a discussion, if the enhancement you’re proposing fits well with our vision for the index, we’ll encourage you to take it to a pull request.
