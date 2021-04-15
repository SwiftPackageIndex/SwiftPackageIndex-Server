---
page-title: FAQ
description: Frequently Asked Questions about the Swift Package Index
---

## Frequently Asked Questions

* [What is the Swift Package Index?](#what-is-the-spi)
* [What is the Swift Package Manager?](#what-is-the-spm)
* [Who built the Swift Package Index?](#creators)
* [Can I support the Swift Package Index?](#support)
* [What happened to the SwiftPM Library?](#swiftpm-library)
* [How does the Swift Package Index work?](#how-does-it-work)
* [What about the GitHub Package Registry?](#package-registry)
* [How is the Swift language and platform support calculated?](#language-and-platforms)
* [What do the license colours mean?](#licenses)
* [Can I contribute to the Swift Package Index?](#contributing)
* [Is there an API?](#api)
* [Why are package versions missing?](#missing-versions)

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

<h3 id="support">Can I support the Swift Package Index?</h3>

We'd love to have your support. Thank you! You can read more about [how we are funding this project](https://blog.swiftpackageindex.com/posts/funding-the-future-of-the-swift-package-index/) and [support it via GitHub sponsors](https://github.com/sponsors/SwiftPackageIndex). 

---

<h3 id="swiftpm-library">What happened to the SwiftPM Library?</h3>

This site is a spiritual successor and replacement for [the SwiftPM Library](/images/swiftpm-library.png). It has been re-implemented from scratch in Swift using Vapor and has had a name change at the same time. We learned many valuable lessons from the original implementation, and the Swift Package Index is the future of Swift package search.

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
  <source srcset="/images/languages-and-platforms~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/languages-and-platforms~light.png" alt="Language and Platform information on a package page">
</picture>


To determine what versions of Swift a package supports, and what platforms it is compatible with, the Swift Package Index runs real-world builds using several Swift compilers targeting several different platforms. You can learn more about how we do this in the [Swift Package Index Build System FAQ](/docs/builds).

---

<h3 id="licenses">What do the license colours mean?</h3>

If a package's license shows with a background that is orange or red, it is for one of three reasons:

1. The package does not have a license.
2. We're unable to detect the software license that the package uses.
2. The license chosen by the package authors is incompatible with the terms and conditions of the App Store.

#### No License

If the package license is showing as "No License", it means we could not find *any* license information in the package repository.

If you are considering using a package that does not have a license, you should be aware that it presents a significant legal risk. Code without a license is not open-source, and the original author reserves all rights by default. For more information, read [this great blog post](https://expressionengine.com/blog/the-truth-about-the-risks-of-unlicensed-software) on the significant risks of using unlicensed code.

If you are the package author, you can fix this by adding a `LICENSE` file with an open-source license that is compatible with the terms and conditions of the App Store. The Swift Package Index will update license metadata a few hours after you push a license to the repository.

#### Unknown License

If the package license is showing as "Unknown License", it means we have been unable to detect the license. It may be an open-source license where GitHub's license detection algorithm has failed, or it could be a completely different type of license, such as a commercial license. If you are considering using a package with an unidentified license, you should check the package's repository for the license details.

If you are the package author of a package showing an unknown license, and you believe it should show a valid open-source license, please [see GitHub's documentation](https://help.github.com/en/github/creating-cloning-and-archiving-repositories/licensing-a-repository#detecting-a-license). The Swift Package Index will update licenses a few hours after GitHub recognises a valid license.

#### Incompatible license

If the package license shows with an orange background but does *not* say "No License" or "Unknown License", then the package is using a license which is incompatible with the terms and conditions of the App Store, such as any GPL style license. If you are considering shipping your app to the App Store, you should be aware that using code licensed under one of these licences presents a legal risk.

---

<h3 id="contributing">Can I contribute to the Swift Package Index?</h3>

Absolutely. The Swift Package Index is [open-source](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server), and we’d love it if you wanted to help us make it better. Please see the [guide to contributing](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/blob/main/CONTRIBUTING.md) for more information.

All participation in this project, whether it be contributing code or discussions in issues are subject to our code of conduct. Please read the [code of conduct](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/blob/main/CODE_OF_CONDUCT.md) for more information.

---

<h3 id="api">Is there an API?</h3>

Not right now. The Swift Package Index is in a period of rapid development right now, and we'd like the flexibility to change things around at this stage in the project's life. It's on the list for the future though!

---

<h3 id="missing-versions">Why are package versions missing?</h3>

Package releases must use git tags that are *fully qualified* [semantic versions](https://semver.org). For example, `2.6.0` is a valid semantic version number, and `2.6` is not.

A good way to check what the latest semantic version release of a package is is to add it to a project in Xcode. By default, Xcode will show the latest semantic version when adding the package to a project. The number you see on this site should match the version Xcode shows when adding the package. If you see something different, please [raise an issue](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/new/choose)!

<picture class="shadow">
  <source srcset="/images/add-package-in-xcode~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/add-package-in-xcode~light.png" alt="Adding a package in Xcode">
</picture>
