---
date: 2023-06-29 12:00
title: Supporting visionOS
description: We’ve added support for visionOS to our compatibility testing, showing it on the package pages and build badges.
---

Apple was quick to release the promised visionOS SDK only a week after WWDC 2023, and today we’re happy to announce that we have already started compatibility testing for this exciting new platform.

That means we’ve begun **building all packages in the Swift Package Index with the visionOS SDK** released earlier this week.

You can find visionOS compatibility information in both the build matrix on the package page and our [shields.io build badges](/posts/launching-language-and-platform-package-compatibility#badges).

<picture class="shadow">
  <source srcset="/images/visionos-build-results~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/visionos-build-results~light.png" alt="A build compatibility matrix showing compatibility with visionOS.">
</picture>

**Note:** Just with the Swift 5.9 builds, it will take a short while for our build system to process the backlog of visionOS builds for all packages. Since we are only building visionOS for Swift 5.9, this backlog is much shorter, and we expect to fill in the question marks in the visionOS column of the build matrix swiftly over the coming days.
