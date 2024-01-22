---
date: 2021-10-18 12:00
title: Package Dependencies - Step One
description: In pursuit of helping you make better decisions about the packages you depend on, we’re taking a step towards exposing dependency information for all packages!
---

We’ve said several times on this blog that one of the primary goals of the [Swift Package Index](https://swiftpackageindex.com) is to help you make better decisions about the dependencies you include in your Swift projects.

In pursuit of that goal, we just launched a new feature that shows you how many dependencies each of the packages in our index has. 🚀

Even better, it doesn’t just give you the number of top-level dependencies that a package declares in its `Package.swift` file. Instead, we inspect the `Package.resolved` file after the [build system](/posts/launching-language-and-platform-package-compatibility) has done the hard work of dependency resolution.

<picture class="shadow">
  <source srcset="/images/dependency-metadata~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/dependency-metadata~light.png" alt="Package metadata showing that the package being inspected depends on nine other packages.">
</picture>

That said, while this feature adds value and we’re happy to get it launched, this is step one towards where we’d like to be with dependency metadata. Some things to note:

- The number shown is a count of _all_ dependencies, both package and test dependencies. Test dependencies are far less impactful when evaluating how a package will impact your project, and it’d be great if we could remove those dependencies from the total. Tracked as [Issue 1300](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1300).
- It would be great to have a visualisation of the dependency tree for each package. This would be useful both for people browsing packages but also for package authors, allowing them to see the story behind each of their dependencies.
- We’d also love to get information into the index about how many packages depend on each package. This would be great for curious package authors but also is a strong signal of quality.

However, what we have for now is still a step in the right direction!
