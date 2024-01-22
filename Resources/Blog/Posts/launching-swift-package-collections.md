---
date: 2021-06-09 12:00
title: Launching Swift Package Collections
description: What are package collections? JSON descriptions of Swift package metadata. What does the Swift Package Index have in droves? Metadata about Swift packages! As soon as we heard about package collections in Swift 5.5, we knew we had to support it.
---

It's probably not news that [this is a big week](https://developer.apple.com/wwdc21/) for Swift developers! On Monday, Apple kicked WWDC off by releasing the first beta of Xcode 13, including Swift 5.5. We've been following the release of the Swift Package Manager in Swift 5.5 closely as it implements package collections, a significant new feature.

What are package collections? JSON descriptions of Swift package metadata. What does the Swift Package Index have in droves? Metadata about Swift packages! As soon as we heard about [the proposal](https://forums.swift.org/t/se-0291-package-collections/41905), we knew we had to support it. For a comprehensive description of the feature, [check out the post over on the official Swift blog](https://swift.org/blog/package-collections/).

We have big plans for package collections, but we wanted to ship something alongside this first beta release. We chose to implement author collections, a list of all packages from the index grouped by repository owner. For example, you can get a package collection containing [all packages from Alamofire](https://swiftpackageindex.com/Alamofire) or [all packages from Point-Free](https://swiftpackageindex.com/pointfreeco).

We expected this feature to roll out as part of the Swift Package Manager command-line tool, and it did. What we didn't expect was full support for package collections in Xcode 13! What a pleasant surprise that was. 😍

We've written up the details of [how to access collections on the Swift Package Index](https://swiftpackageindex.com/package-collections), including how to add them to Xcode _and_ use them from the command line. We'd love for you to [check it out](https://swiftpackageindex.com/package-collections).

However, that wasn't the only surprise this week had in store for us! As we watched [Nicole Jacque](https://twitter.com/racer_girl27) talk about [What's new in Swift](https://developer.apple.com/videos/play/wwdc2021/10192/), we were amazed to see a screenshot of the Swift Package Index appear on the screen and hear Nicole start to talk about it. Remarkable!

<picture class="shadow">
  <source srcset="/images/swift-package-index-whats-new-in-swift-wwdc-2021~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/swift-package-index-whats-new-in-swift-wwdc-2021~light.png" alt="The Swift Package Index site being presented in What's new in Swift at WWDC 2021">
</picture>

We're so happy that Apple sees what we've been working on here as important enough to mention in a WWDC session, and we'd like to thank everyone who was involved in that decision for including us. It's a great honour and one that we do not take lightly.
