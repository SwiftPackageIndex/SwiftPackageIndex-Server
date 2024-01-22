---
date: 2023-06-12 12:00
title: Supporting Swift 5.9 Betas
description: How could we improve on adding support for a new Swift version after just one week of it being available? We could add support for Swift 5.9 one week after the release of the first beta version!
---

Back in April, we were [proud to announce that we supported Swift 5.8 within one week of the official release](https://blog.swiftpackageindex.com/posts/supporting-swift-58/), adding it to our compatibility matrix so you could know whether the package you were considering would work with the latest version of Swift.

How could we improve on adding support for a new Swift version after just one week of it being available? We could add support for Swift 5.9 one week after the release of the _first beta version_!

So, that’s the announcement! The Swift Package Index **now supports Swift 5.9 packages** and will [soon show macro products](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2426) contained within them.

<picture>
  <source srcset="/images/swift59-build-results~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/swift59-build-results~light.png" alt="A build compatibility matrix showing compatibility with Swift 5.9.">
</picture>

We also support building documentation with Swift 5.9, but as it’s still in beta, we have made that opt-in for now. If you’d like to build your package documentation with 5.9, you can [let us know via a `.spi.yml` manifest file](https://github.com/fruitcoder/extract-case-value/pull/1/files) in your package’s repository.

**Note:** For the next few days, you may see question mark icons against the Swift 5.9 beta column in the matrix. Please bear with us while our systems process the build backlog.
