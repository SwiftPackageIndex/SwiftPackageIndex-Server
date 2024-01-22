---
date: 2022-12-14 12:00
title: Recognising Package Authors
description: The Swift Package Index now recognises primary contributors to open-source Swift packages by including author information alongside package metadata. Thank you to everyone who contributes to open-source Swift software!
---

When we launched this site back [in June 2020](https://iosdevweekly.com/issues/460#start), one of the features on the “must be done before launch” list was support for showing who wrote each package. Not just a GitHub username but the names of the primary contributors.

We didn’t quite get that feature in for launch, and then other things took priority as we started dealing with real users and the day-to-day running of the site. Then we tackled [build compatibility](https://blog.swiftpackageindex.com/posts/launching-language-and-platform-package-compatibility/), [documentation](https://blog.swiftpackageindex.com/posts/versioned-docc-documentation/), and many other features.

We never returned to author information. Until now!

The Swift Package Index project participated in the [Swift Mentorship Program](https://www.swift.org/mentorship/) again this year, and we’re delighted to say that [Javier Cuesta](https://github.com/jcubit) has done outstanding work resurrecting this feature from the depths of the issue backlog!

<picture class="shadow">
  <source srcset="/images/author-metadata~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/author-metadata~light.png" alt="The Swift Package Index site showing author metadata for the fastlane package.">
</picture>

By default, we try to determine who has contributed the most to a package and include their name(s). Then, if there are more contributors, we’ll say how many.

All this information comes from git history, and the automated mechanism and algorithm we have used may not get it right. With that in mind, we also allow package authors to override the display of author information through the `.spi.yml` file.

Adding a top-level `metadata` key with an `authors` key below it will override any automatic author information entirely. For example:

```yml
version: 1
metadata:
  authors: “Written by Person One, Person Two, and other contributors.”
```

We want to thank everyone who contributes to open-source software, and we hope this feature helps authors get credit for their efforts.

We’d also like to thank Javier for his hard work and always-positive attitude on this feature. Every aspect of working with him was a pleasure, and this feature only exists today because of his efforts.
