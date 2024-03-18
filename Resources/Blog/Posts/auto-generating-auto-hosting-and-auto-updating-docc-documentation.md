
> **UPDATE:** The information in this blog post is superceded by our [official documentation](https://swiftpackageindex.com/SwiftPackageIndex/SPIManifest/documentation/spimanifest/commonusecases). Please refer to the documentation rather than this blog post.

Introduced at WWDC 2021, [DocC](https://developer.apple.com/documentation/docc) is Apple’s recommended way to provide documentation for your packages.

It’s easy to use, and the resulting documentation looks great. It generates documentation either from comments or separate article files written in Markdown that is more suitable for longer-form documentation. You can even use it to create beautiful interactive tutorials with images and step-by-step instructions. DocC generates either an Xcode documentation archive or a set of HTML and CSS files that you can host on a web server.

Of course, having a directory full of HTML is only half the battle. Your next task is to get it hosted somewhere online and maybe even set up a CI task to automate that process so that your published documentation stays up-to-date as your development progresses.

That’s where our latest feature will come in handy, and we’re launching it today!

### Auto-generated, auto-hosted, and auto-updating

Our build system can now generate and host DocC documentation and make it available from your package’s page in the index. All we need is a little configuration data so that we know how best to build your docs.

Once configured, you will see a new “Documentation” link in the sidebar and never have to worry about your documentation again!

<picture class="shadow">
  <source srcset="/images/blog/documentation-menu-link~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/blog/documentation-menu-link~light.png" alt="The DocC package page showing a link to the auto-generated and hosted documentation.">
</picture>

As a package author or maintainer, there are only ~~three~~two things you need to do for the Swift Package Index to build and host your documentation.

1. Ensure that your package builds successfully with Swift 5.6. Your package can support earlier versions of Swift, too, but must successfully build with 5.6.
2. ~~Add the [swift-docc-plugin](https://github.com/apple/swift-docc-plugin) documentation plugin to your package’s `Package.swift` manifest file, if you haven’t done so already.~~
3. Create a `.spi.yml` file and commit it to the root of your package’s repository, telling our build system which targets have documentation.

From there, we’ll take care of everything else. Every time you push new commits to your package, we’ll regenerate your documentation.

<h3 id="adding-the-docc-plugin">Adding the Swift DocC plugin</h3>

> **UPDATE:** It’s no longer necessary to add the DocC plugin to your package. If you’ve added it already, feel free to remove it. Our build system will also cope if you leave the plugin or need it for another purpose, so there’s no rush to remove it! The only change you need to make to your project is to [add the manifest file](#add-a-spi-manifest).

You may already have taken this first step if you’ve worked with DocC locally. If not, then add the following lines to the end of your `Package.swift`:

```swift
#if swift(>=5.6)
  // Add the documentation compiler plugin if possible
  package.dependencies.append(
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
  )
#endif
```

Making the plugin dependency conditional means that nothing will break even if the `swift-tools-version` of your manifest is for an earlier version of Swift than 5.6. Naturally, this is unnecessary if your package _only_ supports Swift 5.6 and above.

<h3 id="add-a-spi-manifest">Add a Swift Package Index manifest file</h3>

Then, create and commit a manifest file named `.spi.yml` file in the root of your repository that looks something like this:

```yaml
version: 1
builder:
  configs:
    - documentation_targets: [Target]
```

This file tells our build system to generate documentation for the target `Target`. You would typically set this as your package’s main (or only) target, but it may also be a dedicated target containing documentation Markdown files.

You can also specify multiple targets, and we’ll add a target switcher in the hosted documentation so people can easily find _all_ your documentation!

### Documentation platform

By default, we will generate documentation using macOS. If your package requires the documentation generation to be run for a certain platform such as iOS, you can also specify a platform:

```yaml
version: 1
builder:
  configs:
    - platform: ios
      documentation_targets: [Target]
```

### Auto-updating frequency

To keep the amount of processing that our build servers perform under control, we only build the default branch for each package at most once every 24 hours. So, when you push the configuration file live, the system will generate that set of documentation, but it will then be 24 hours until the generation process runs again. If there have been any commits during that period, we’ll create docs from the latest commit when the period resets.

<picture class="shadow">
  <source srcset="/images/blog/hosted-docc-documentation~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/blog/hosted-docc-documentation~light.png" alt="Hosted documentation for the DocC package shown in the context of the Swift Package Index with a header above the documentation.">
</picture>

### Initial adopters!

**Note:** We'd like to thank the following package authors for coming on board with our documentation hosting feature so early. The feature is fully released and stable now and available for *all* package authors. for more information, see our [SPIManifest documentation](https://swiftpackageindex.com/swiftpackageindex/spimanifest/0.13.0/documentation/spimanifest/commonusecases).

You may have seen a [call for package authors with DocC compatible documentation](https://twitter.com/SwiftPackages/status/1531299947462676480) earlier this week, and we’re thrilled to say that we have 20 packages that have already added configuration files and have their documentation hosted by us! Why not check them out?

- [bytes](https://swiftpackageindex.com/tbointeractive/bytes) by [TBO Interactive](https://swiftpackageindex.com/tbointeractive)
- [Compute](https://swiftpackageindex.com/AndrewBarba/swift-compute-runtime) by [Andrew Barba](https://swiftpackageindex.com/AndrewBarba)
- [GeoJSONKit](https://swiftpackageindex.com/maparoni/GeoJSONKit) by [Maparoni](https://swiftpackageindex.com/maparoni)
- [mqtt-nio](https://swiftpackageindex.com/swift-server-community/mqtt-nio) by [Swift On Server Community](https://swiftpackageindex.com/swift-server-community)
- [ParseSwift](https://swiftpackageindex.com/parse-community/Parse-Swift) by [Parse Platform](https://swiftpackageindex.com/parse-community)
- [RevenueCat](https://swiftpackageindex.com/RevenueCat/purchases-ios) by [RevenueCat](https://swiftpackageindex.com/RevenueCat)
- [Runestone](https://swiftpackageindex.com/simonbs/Runestone) by [Simon Støvring](https://swiftpackageindex.com/simonbs)
- [Saga](https://swiftpackageindex.com/loopwerk/Saga) by [Loopwerk](https://swiftpackageindex.com/loopwerk), who very kindly [sponsors this project through GitHub Sponsors](https://github.com/sponsors/SwiftPackageIndex).
- [ScaledFont](https://swiftpackageindex.com/kharrison/ScaledFont) by [Keith Harrison](https://swiftpackageindex.com/kharrison)
- [SemanticVersion](https://swiftpackageindex.com/SwiftPackageIndex/SemanticVersion) by [Swift Package Index](https://swiftpackageindex.com/SwiftPackageIndex) (well, we couldn’t ship this without one of our packages having documentation, right? 😂)
- [SpanGrid](https://swiftpackageindex.com/sherlouk/SpanGrid) by [James Sherlock](https://swiftpackageindex.com/sherlouk) who also very kindly [sponsors this project through GitHub Sponsors](https://github.com/sponsors/SwiftPackageIndex) and is our [top contributor](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/graphs/contributors) outside the core team!
- [StreamChat](https://swiftpackageindex.com/GetStream/stream-chat-swift), [StreamChatSwiftUI](https://swiftpackageindex.com/GetStream/stream-chat-swiftui), and [EffectsLibrary](https://swiftpackageindex.com/GetStream/effects-library) by [Stream](https://swiftpackageindex.com/GetStream), who very kindly [sponsor this project](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server#corporate-sponsors).
- [swift-bundler](https://swiftpackageindex.com/stackotter/swift-bundler) by [stackotter](https://swiftpackageindex.com/stackotter)
- [swift-composable-architecture](https://swiftpackageindex.com/pointfreeco/swift-composable-architecture) by [Point-Free](https://swiftpackageindex.com/pointfreeco), who also very kindly [sponsor this project through GitHub Sponsors](https://github.com/sponsors/SwiftPackageIndex).
- [SwiftDocC](https://swiftpackageindex.com/apple/swift-docc) and [swift-markdown](https://swiftpackageindex.com/apple/swift-markdown) from [Apple](https://swiftpackageindex.com/apple). Without these packages this project would not have been possible and we'd like to say a big thank you to all the members of those teams at Apple! ❤️
- [TGCardViewController](https://swiftpackageindex.com/skedgo/TGCardViewController) by [SkedGo](https://swiftpackageindex.com/skedgo)

If you maintain one of the 4,600+ packages we have in the index, please add your configuration file to opt-in to having your documentation hosted on the Swift Package Index, and we’ll take care of everything else. If you have any issues, please [join us on Discord](https://discord.gg/vQRb6KkYRw) or [raise an issue](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/new/choose).

### Next steps

We’re proud of what we have built here, but we’re not done with this feature yet.

There’s a write up of things we want to tackle next [on our Discussion forum](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/discussions/1590#discussioncomment-2784226), but to summarise, this is what we’re planning to work on next:

- Versioned documentation with stable URLs. You’ll be able to read documentation for the exact version of a package you’re using in your projects.
- Easy switching between documentation versions. Once we have versioned documentation, we’re planning to clarify where the documentation you’re reading has come from. If you’re looking at default branch documentation, you’ll be able to see that. Same if you’re looking at a tagged version. We’ll also make it easy to switch between documentation sets for each package.
