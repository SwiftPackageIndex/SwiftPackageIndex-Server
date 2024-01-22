---
date: 2021-05-18 13:00
title: What’s Next? - May 2021
description:
---

You might just have finished reading our [progress report from the last three months](/posts/progress-update-may-2021/). Now it’s time to talk about what we’re planning for the next few months!

Like last time, this is a list of areas that we’ll focus on over the next few months, not a to-do list. Other features and bug fixes will crop up and might take priority, and that’s OK! It’s good to have a rough direction in mind, though.

## Author Information

We feel strongly that open-source package authors should be acknowledged for their work. The very first designs for the package index had author information right at the top of the package metadata, but it didn’t quite make it into our feature set at launch. We want to change that, adding author information prominently at the top of our package metadata section.

We’ll collect the author information via the `.spi.yml` file [we already use](/posts/the-swift-package-index-metadata-file-first-steps) for build configuration.

## Package Keywords

We’ve long debated whether packages should have categories that come from a pre-determined list or have freeform keywords. After giving it some thought we’re going to go with freeform keywords rather than categories. We’ll collect keyword metadata from [GitHub topics](https://github.blog/2017-01-31-introducing-topics/) and show the keywords on package pages.

## Dependency Information

We’d also like to start working towards displaying the dependencies that a package would bring into your project if you use it. For example, we might start by adding a simple count of top-level and total dependencies.

## Additional Package Metadata

We’d also love to pick up a few more data points about every package. Does a package have tests? Is source code available? Is it a fork of another package? All of these are good indicators when considering dependencies.

## Home Page Redesign

Using the author information and keyword information mentioned above, we’d love to work on a much more information-rich home page. The first part of this is to think about it properly and put together a design, which is why we’re not going to talk about _precisely_ what you can expect today. However, we’ll be working on this.

## Package Collections

Finally, we’d like to finish off our support for Package Collections and put it live to coincide with the release of Swift 5.5. Initially, we’ll support collections that show all packages authored by their repository owner. So, for example, a collection of [these packages from Apple](https://swiftpackageindex.com/apple), or [these packages from the Vapor project](https://swiftpackageindex.com/vapor).
