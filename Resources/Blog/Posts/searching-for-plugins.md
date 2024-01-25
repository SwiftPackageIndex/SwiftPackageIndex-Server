---
date: 2022-07-12 12:00
title: Searching for plugins?
description: With Swift 5.6, Xcode and the Swift Package Manager gained a new product type, plugins, and we’re delighted to announce we now have support for filtering search results by whether or not they include a plugin.
---

With Swift 5.6, Xcode and the Swift Package Manager gained a new product type, plugins, allowing developers to extend their build process with new build commands or processing steps.

Here are two WWDC 2022 sessions that go into more detail on what plugins are and how you can create them:

- [Meet Swift Package plugins](https://developer.apple.com/wwdc22/110359)
- [Create Swift Package plugins](https://developer.apple.com/wwdc22/110401)

What use are plugins? Rather than link to some examples directly, let’s use the latest feature of the Swift Package Index to find out! You can now filter search results based on whether packages include a plugin.

[Search for packages containing a plugin](https://swiftpackageindex.com/search?query=product%3Aplugin)

As you’ll notice, there are packages containing plugins to help you [generate documentation](https://swiftpackageindex.com/apple/swift-docc-plugin) (and you can [find out more about that here, too](https://blog.swiftpackageindex.com/posts/auto-generating-auto-hosting-and-auto-updating-docc-documentation)), [integrating SwiftLint](https://swiftpackageindex.com/lukepistrol/SwiftLintPlugin), and a few more!

This feature has been a group effort by several contributors! [Joe Heck](https://twitter.com/heckj) first [suggested it would be a helpful feature](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/discussions/1661), and [Marin Todorov](https://twitter.com/icanzilb) took up the challenge and implemented it! We’re so happy to accept this contribution which means we have support for plugins just a few weeks after Apple officially introduced them at WWDC.

Thanks to open source contributions, our search is improving!
