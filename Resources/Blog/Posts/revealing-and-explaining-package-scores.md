---
date: 2023-10-31 12:00
title: Revealing and explaining package scores
description: When you search the Swift Package Index, the order in which the search results are displayed is determined by a combination of the relevance of text in the package name and description, and an internal score based on various metrics. Today, we're adding a feature that
---

This guest post is from [Cyndi Chin](https://cyndichin.github.io/) and announces the results of her work for this year’s [Swift Mentorship Program](https://www.swift.org/mentorship/).

Working with Cyndi over the past twelve weeks has been an absolute pleasure. Her enhancements meaningfully push the Swift Package Index forward by making our internal package ranking algorithm transparent, allowing package authors to understand our search results better.

One of Cyndi’s goals was to be involved in shipping something from beginning to end, and the end of that process is the announcement of the feature going live on the site! So, I’ll finish by saying a huge thank you to Cyndi for all of her hard work and hand you over to her for the rest of this post so she can make today’s announcement.

---

When you search the Swift Package Index, we determine the order in which we show search results by two primary factors: the relevance of the text in the package name and description and an internal score based on various metrics.

Until now, this score was not publicly visible on the site, but as of today, we publish it publicly in a new [Package Score](https://swiftpackageindex.com/apple/swift-markdown/information-for-package-maintainers#package-score) section on every [Package Maintainer’s page](https://swiftpackageindex.com/apple/swift-markdown/information-for-package-maintainers). We also deployed two additional metrics that contribute to the score.

### What is a package score?

In combination with the relevancy of a search query, we use a package score to partially influence the ordering of search results on the Swift Package Index. The new information gives package authors and maintainers insight into how we calculate package scores, and the metrics that calculation relies on, such as how actively maintained a package is, whether it has documentation, tests, and various other factors.

<picture class="shadow">
  <source srcset="/images/package-maintainers-score-section~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/package-maintainers-score-section~light.png" alt="The package score section on the package maintainer's page showing a breakdown of package score for a package.">
</picture>

While the algorithm for calculating package scores [has always been publicly available](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/blob/main/Sources/App/Core/Score.swift), it’s unreasonable to expect people to browse the source code to see how we score packages. Today’s release makes the scoring process much more transparent.

### Score traits

The package score is currently evaluated based on ten score traits. Previously, we relied on eight attributes to determine a package’s score.

- Whether the package is archived or not (Up to 20 points)
- Whether the package has an open-source license that is compatible with the App Store (Up to 10 points)
- The number of releases (Up to 20 points)
- The number of stars (Up to 37 points)
- The number of dependencies (Up to 5 points)
- The latest activity (Up to 15 points)
- Whether the package has documentation (Up to 15 points)
- The number of contributors (Up to 10 points)

### Adding new score traits

Along with introducing the package score section to the maintainer’s page, we have included two additional score traits in our assessment.

- Whether the package has any test targets (Up to 5 points)
- Whether the package has a README file (Up to 15 points)

There is always room for further improvement to the package score, and these ten traits are just the start of making this score more comprehensive.

### Finding your package’s score

As a package author, if you’d like to see the breakdown of your package score, find the “Do you maintain this package?” section at the bottom of the right-hand sidebar on your package page, and you’ll find the score breakdown at the end.

<picture class="shadow">
  <source srcset="/images/find-package-maintainers-page~dark.png“ media=“(prefers-color-scheme: dark)">
  <img src="/images/find-package-maintainers-page~light.png" alt="The location of the Learn More link that takes package authors to the package maintainer’s page for their package.">
</picture>

If you have any feedback regarding the package score or suggestions on how we can improve it, we would love to hear your thoughts in our [discussion forum](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/discussions/2591). We appreciate any contributions as we continue to enhance the package score system.

As a final note to this post, I can't express how thankful I am to have had Dave as my mentor in the Swift Mentorship program. Contributing to this project under his guidance has been an incredible learning experience and I'm grateful for the knowledge, support, and inspiration he has provided me. Thank you Dave!
