---
date: 2021-12-15 12:00
title: Improvements to package search
description: Recently, we’ve been focusing our attention on improving search here on the Swift Package Index, and it’s time to let you all know what we’ve implemented!
---

Recently, we’ve been focusing our attention on improving search here on the Swift Package Index, and it’s time to let you all know what we’ve implemented!

### Search Results

First up, we improved the information you’ll see when you see search results or any list of packages:

<picture class="shadow">
  <source srcset="/images/search-results~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/search-results~light.png" alt="Search results that include the number of stars a package has and when the repository last had maintenance activity, in addition to the standard metadata.">
</picture>

All package lists across the whole site now include the number of stars and how recently a package has had maintenance activity so you can start making some decisions before you even open a package page. You can see examples of this in [search results](https://swiftpackageindex.com/search?query=http), [keyword results](https://swiftpackageindex.com/keywords/rxswift), and [owner/author pages](https://swiftpackageindex.com/apple).

**Note:** We update the date of the last “maintenance activity” when there is a commit to the default branch or when someone closes or merges an issue or pull request.

### Search Filters

We’ve also added filters so you can refine any set of search results. The best way to explain this feature is with some examples:

- [Packages matching “http” that are compatible with iOS and Linux](https://swiftpackageindex.com/search?query=http+platform%3Aios%2Clinux).
- [Packages matching “URLSession” that have had maintenance activity within the last three months](https://swiftpackageindex.com/search?query=URLSession+last_activity%3A%3E2021-09-16).
- [Packages matching “chart” that are licensed with App Store compatible licenses](https://swiftpackageindex.com/search?query=chart+license%3Acompatible).
- [Packages matching “layout” that have more than 5,000 stars](https://swiftpackageindex.com/search?query=layout+stars%3A%3E5000).

[Head over to the documentation](https://swiftpackageindex.com/faq#search-filters) for more information on all the fields you can filter on and more information on this significant feature.

<picture class="shadow">
  <source srcset="/images/search-filters~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/search-filters~light.png" alt="Search results that have filters applied to narrow down the results based on last maintenance activity and platform compatibility.">
</picture>

We’re [not entirely done with updates to search](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/projects/9) yet, but what we have is certainly significant enough for an update post!

As always, all of this work is a team effort, and these improvements would not exist without the invaluable contributions of [James Sherlock](https://github.com/Sherlouk), who did the lion’s share of the work getting filters implemented and [Sarah Lichter](https://github.com/selichter), who helped with the package list improvements. Thank you both!
