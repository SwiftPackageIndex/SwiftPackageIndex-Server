---
date: 2020-08-20 12:00
title: Launching Language and Platform Package Compatibility
description: We decided that one of the most important pieces of information we could provide on a package metadata page was what versions of Swift, and what platforms it was compatible with. Building that feature turned out to be quite an epic journey.
---

What’s the first question you need an answer to after finding a package that fits your needs?

> “Does this package work with the Swift version and platform that my app uses?”

When we initially launched the Swift Package Index, we attempted to answer this question with the metadata available in the package manifest. Namely the [`swiftLanguageVersions`](https://developer.apple.com/documentation/swift_packages/package/3197887-swiftlanguageversions) and [`platforms`](https://developer.apple.com/documentation/swift_packages/package/3197886-platforms) properties.

The problem is that neither of those properties is perfect. `swiftLanguageVersions` isn’t granular enough, only [officially](https://developer.apple.com/documentation/swift_packages/swiftversion) allowing values of `v4`, `v4_2`, and `v5`. The `platforms` property is better, but doesn’t let package authors declare compatibility with non-Apple operating systems such as Linux.

Wouldn’t it be fantastic if you could see a matrix like this for _every_ package? 😍

<picture class="shadow">
  <source srcset="/images/promisekit-language-and-platform-metadata~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/promisekit-language-and-platform-metadata~light.png" alt="The language and platform compatibility matrix for PromiseKit.">
</picture>

Look at how information-rich that matrix is. You can instantly see that the latest stable version of [PromiseKit](https://swiftpackageindex.com/mxcl/PromiseKit) is compatible with every version of Swift back to 4.2, and every platform, including Linux. Then, you can see that the alpha version in development drops support for iOS, tvOS, and watchOS, and Swift 4.2. That seems suspicious, right? Keep looking, and you’ll see that the default branch fixes all those issues and restores compatibility. I’m confident looking at that matrix that when 7.0.0 is released, it’ll have green ticks across the board, but I also know to not depend on this current alpha. That’s practical, actionable information.

When we started thinking about how best to solve this problem, the obvious best solution was to build the packages! What better way to see if a package is compatible with Swift 4.2 than to build it with the version of `xcodebuild` that shipped with Xcode 10.1.

So that’s what we did, and it’s available right now. Why not [give it a try](https://swiftpackageindex.com) by searching for a few of your favourite packages? 🚀

### Accurate, real-world compatibility data

It’s a little more complicated than “just build each package” though. A package might build with Swift 5.2 on iOS, but that same build might fail using Swift 5.2 on macOS due to a UIKit dependency, or other macOS specific issue. What’s needed is a _matrix_ of builds to generate an accurate picture of compatibility.

So, if we run builds using Swift 5.1 on iOS, macOS, tvOS, watchOS, and with Linux and _any_ of them pass, it’s compatible with Swift 5.2. If _any_ version of Swift builds without failure on iOS, then the package supports iOS.

We ended up with a platform list of:

- iOS using `xcodebuild`
- macOS using `xcodebuild`
- macOS using `swift build` (there are good reasons where `swift build` would pass in circumstances where `xcodebuild` might fail)
- macOS using `xcodebuild` on Apple Silicon (yes, compiled using a DTK!)
- macOS using `swift build` on Apple Silicon
- tvOS using `xcodebuild`
- watchOS using `xcodebuild`
- Linux using `swift build`

We then decided on a list of Swift compiler versions we’d like to check compatibility with:

- Swift 4.2 (4.2.1)
- Swift 5.0 (5.0.1)
- Swift 5.1 (5.1.3)
- Swift 5.2 (5.2.4)
- Swift 5.3 (beta)

That’s up to 32 builds per package, but that’s just the beginning. What if there’s a stable release and a beta release? The stable version might support Swift 4.2 and higher, and the new beta might drop support for anything less than Swift 5.2. That’s information which would be important when choosing a package, so we need to show it. As we also track the status of the default branch, we must build that too, and we’ve quickly arrived at a place where we might need to run 96 builds _per package_! With almost 3,200 packages in the index, that’s potentially more than 300,000 builds! 😅

In practice, it’s less than that as most packages don’t have a current beta release, but it’s still a _lot_ of builds. We’ve processed more than 200,000 builds as I write this, and we’re not quite finished. As of today, we’re at 99% though, so we almost made it before launch! 😬

If you’ve been following [these tweets](https://twitter.com/daveverwer/status/1291808885259620353), it should be obvious what all that processing was! Let’s take a look at the last **30 days** of CPU graphs for our production server, a 2018 Mac mini with 32Gb RAM and a 6-core i7 CPU:

![A graph showing a few spikes of CPU activity, followed by a sustained 100% CPU load.](/images/production-server-thirty-day-cpu-graph.png)

You can see a few of our final test runs in that graph, and then we started processing for real. Since then, we’ve kept the CPU completely pegged for more than two weeks. We’ve also had our staging Mac mini, a spare 2016 MacBook Pro, and a DTK working on builds too.

### <a id="badges"></a> Everyone loves badges

Providing compatibility information on this site is one thing, but everyone loves adorning their packages pages with [shields.io](https://shields.io) badges, don’t they? If you maintain an open-source project, wouldn’t you like to show off real compatibility status in your README file, like this?

![A screenshot of a GitHub page with badges that show the Swift and platform compatibility for the package.](/images/rester-readme-with-spi-badges.png)

If you’re a package author, click the “Copy badge” button below each of the compatibility matrices and you’ll have a Markdown image link in your clipboard, ready to use.

Your users will always see live, accurate compatibility information that updates whenever you release a new version.

### Credit where it’s due!

First of all, we’d like to thank our kind friends at [MacStadium](https://macstadium.com) for providing the significant hosting resources for this project as part of their [open-source programme](https://www.macstadium.com/opensource). At one point we were a little concerned that we might melt their machines, and we very glad that we didn’t. They’ve performed incredibly.

We also want to say thank you to [Ankit Aggarwal](https://twitter.com/aciidb0mb3r) and [Boris Bügling](https://twitter.com/neonacho) of Apple. Their tireless help and support on the [SwiftPM Slack](https://swift-package-manager.herokuapp.com) saved us countless hours figuring out the correct way to approach this problem.

Finally, we’d love to say thank you to everyone who provided help and feedback along the way as we built this feature. We couldn’t have done it without any of you.

### Wrapping up

Some package authors set up continuous integration for their packages and of course, that includes a build step. That usually only covers one version of Swift though, and the information gets hidden away in a different place in each repo. We think that by centralising this data and making it available for _all_ packages, we should be able to help this community make better decisions about their dependencies, and that’s what this site is all about.

We hope you love this feature as much as we do! ❤️
