---
date: 2020-09-09 12:00
title: Building 3,238 Swift Packages for Apple Silicon
description: As part of the Swift Package Index build system, we have processed what must be the most extensive test of Apple Silicon compatibility outside of Apple. Here’s what we found.
---

As part of the [Swift Package Index build system](/posts/launching-language-and-platform-package-compatibility/), we have processed what must be the most extensive test of Apple Silicon compatibility outside of Apple.

At the time of writing, we currently have 12,942 Apple Silicon builds in our database covering 3,238 packages. Why so many? We test up to [three versions of each package](https://swiftpackageindex.com/SwifQL/SwifQL/builds) and compile each version with both `xcodebuild` and `swift build`.

I’m sure that many of the Apple Silicon DTK machines Apple shipped around the world are working very hard, testing apps for compatibility, but I’m not sure any of them have worked quite as hard as ours has. 🚀

## What did we find?

As you might expect, there’s plenty of good news. For packages with successful Intel builds, the _vast majority_ also successfully build for Apple Silicon. 👍

There are failures, though, and the most interesting failures are where the build fails on Apple Silicon while the corresponding Intel build succeeds. In cases like this, that indicates a compatibility issue that will potentially need some attention from the package author. We’ve identified 139 packages (~4%) where this is the case, and have [compiled a list of them for reference](https://gist.github.com/daveverwer/ae08ad14a7a975e0488503282b4f1dbf).

There are a few common errors that we’re observing in these failures, and most of them are from one of the following problems:

- Any inline assembly will fail, obviously!
- `Float80` is unavailable.
- `x86_thread_state64_t` is unavailable.
- `__darwin_arm_thread_state64' has no member '__rsp'`.
- `cannot convert value of type 'CVaListPointer' to expected argument type '__darwin_va_list?'`.
- Sometimes, the compiler crashes!

Even though 139 failing packages might sound like a lot, it’s not that bad, especially when you consider that many of the failures all fail due to an issue in a common base dependency, [`PerfectLib`](https://swiftpackageindex.com/PerfectlySoft/Perfect).

## Where do we go from here?

Even though the results are generally positive, it does show that there’s a bit of work that the community need to do to ensure the transition to Apple Silicon is as smooth as possible.

If you’re a package author and do not have a DTK machine at your disposal, please feel free to use ours via the Swift Package Index build system! Make changes to your packages, push them to a pre-release tag (for example, X.X.X-arm-beta-X) and the build system will pick up that tag and build it. You should see new build results, usually within a couple of hours of pushing a tag.

If you have any problems with the build system, there’s a couple of ways to contact us. We’re in the `#swiftpackageindex` channel over at the [SwiftPM Slack](https://swift-package-manager.herokuapp.com), or if it looks like there might be something wrong, please [raise an issue on GitHub](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/new).
