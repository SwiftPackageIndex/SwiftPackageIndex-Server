---
page-title: Add a Package
description: Want to add a package to the Swift Package Index? It's easy.
---

## Add a Package

Anyone can add a package to the Swift Package Index. Please feel free to submit any package repository to the index, whether it's a package written by you or someone else. There's also no quality threshold. As long as the packages are valid and meet the requirements below, we will accept them. If you're unsure about any of the requirements, please submit the package(s), and we'll happily provide help.

There are a few requirements for inclusion in the index, but they aren't onerous:

- The package repositories must all be publicly accessible.
- The packages must all contain a valid `Package.swift` file in the root folder.
- The packages must be written in Swift 5.0 or later.
- The packages must all contain at least one product (either library, executable, or plugin).
- The packages should have at least one release tagged as a [semantic version](https://semver.org/).
- The packages must all output valid JSON when running `swift package dump-package` with the latest Swift toolchain.
- The package URLs must include the protocol (usually `https`) and the `.git` extension.
- The packages must all compile without errors.

<a href="https://github.com/SwiftPackageIndex/PackageList/issues/new/choose" class="big_button green">Add Package(s)</a>

<div class="note">
<p><strong>Note:</strong> Our build system can now generate and host DocC documentation and make it available from your package’s page in the index. All we need is a little configuration data so that we know how best to build your docs.</p>
<p><a href="https://blog.swiftpackageindex.com/posts/auto-generating-auto-hosting-and-auto-updating-docc-documentation/">More information here</a>.</p>
</div>

<div class="note">
<p><strong>Note:</strong> If submitting your own packages, don't forget to add shields.io badges to your package's README to always have up to date swift version and platform compatibility information readily available. Once your package appears in the index, use the "Do you maintain this package?" link in the right-hand sidebar of your package page and use the provided markdown.</p>
<p>For example:<br/><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdaveverwer%2FLeftPad%2Fbadge%3Ftype%3Dplatforms"> <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdaveverwer%2FLeftPad%2Fbadge%3Ftype%3Dswift-versions"></p>
</div>

### Removing a Package

You can request to have a package removed from the index with [this GitHub workflow](https://github.com/SwiftPackageIndex/PackageList/issues/new/choose).
