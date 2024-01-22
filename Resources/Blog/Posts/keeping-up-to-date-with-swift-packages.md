---
date: 2020-11-25 12:00
title: Keeping Up To Date with Swift Packages
description: How do you keep up with new releases of the packages you use? How do you discover new packages? It’s a tough challenge to keep up to date with everything that the community releases, so we have some announcements today that can help you stay informed!
---

How do you keep up with new releases of the packages you use? How do you discover new packages? It’s a tough challenge to keep up to date with everything that the community releases, so we have some announcements today that can help you stay informed!

Before we get started with the announcements, we want to credit [James Sherlock](https://twitter.com/JamesSherlouk) for his invaluable contributions to building the Twitter updates feature. He was instrumental in getting this feature up and running and has been making other improvements in several areas of the site since we launched. Thank you, James!

### Updates via Twitter

You may already be following the [@SwiftPackages](https://twitter.com/SwiftPackages) account where we tweet occasional updates about the project. But as of yesterday, we’re also tweeting on the [@PackageFirehose](https://twitter.com/packagefirehose) account. As you might guess by the name, this is a high volume account that posts _every time_ there’s a new package added to the index, and _every time_ there’s a new release of a package that we track. It’s around 20 tweets a day, if that counts as high volume!

<picture class="shadow">
  <source srcset="/images/package-firehose-tweet~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/package-firehose-tweet~light.png" alt="A screenshot of a tweet from the package firehose account.">
</picture>

While we’re on the subject of Twitter, we’d love to know what you’d like to see us do with the [@SwiftPackages](https://twitter.com/SwiftPackages) account. We’ve set up a [short survey](https://iosdevweekly.typeform.com/to/t7uHYvXv) if you have a couple of minutes. We’d love to hear your opinions.

### Updates via RSS

We’ve had RSS support for a while now, but we’ve not talked about it on the blog before, so it’s worth mentioning. If you’d prefer to keep up to date via a feed reader, or if you want fine-grained control over what type of package updates you’d like to be notified of then subscribe to one of our RSS feeds:

- [New Packages](https://swiftpackageindex.com/packages.rss) – A feed with packages that are new to the Swift Package Index.
- [All Package Releases](https://swiftpackageindex.com/releases.rss) – A feed of all new package version releases.

One advantage that these feeds have over Twitter is that they can be filtered with query string parameters. The package releases feed accepts four parameters; `major`, `minor`, `patch`, and `pre`. Pass `true` to any of these parameters to filter the feed on that part of the [semantic version number](https://semver.org). So, you can subscribe to [only major package release](https://swiftpackageindex.com/releases.rss?major=true), or [major and minor package releases combined](https://swiftpackageindex.com/releases.rss?major=true&minor=true), or if you _only_ want to know about pre-release versions, [you can find those here](https://swiftpackageindex.com/releases.rss?pre=true). Use any permutation of the parameters to get exactly the feed that you want.

We hope you find both of these mechanisms for keeping up to date useful!
