---
date: 2021-05-05 13:00
title: Launching the Swift Package Index Playgrounds app for macOS
description: Try out any Swift package in Xcode with just a couple of clicks. It's the launch of the first native app from the Swift Package Index!
---

From the very beginning, the main goal of this site was to do more than echo Swift package metadata. We want to enable better _decisions_ about which dependencies to use. That’s why we include information about how actively maintained a package is, and it’s why we check compatibility with the different platforms by building against them.

Once you’ve decided that a package might be a good fit for your project, what’s your next step? Do you import it and start coding against it?

There’s a better way.

What if you could click a button and open Xcode with a Swift playground that has the library you’re thinking of using already imported? That’s what we’re launching today with the [Swift Package Index Playgrounds](https://swiftpackageindex.com/try-in-a-playground) app.

Once you have installed the app, click “Try in a Playground” from any package page.

<picture class="shadow">
  <source srcset="/images/try-in-a-playground-package-page~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/try-in-a-playground-package-page~light.png" alt="The Swift Package Index site with the Try in a Playground button highlighted">
</picture>

Then click "Create Playground" when the app launches.

<picture>
  <source srcset="/images/spi-playgrounds-app~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/spi-playgrounds-app~light.png" alt="The Swift Package Index Playgrounds app running on macOS">
</picture>

Choose where to save it, and a few seconds later, the playground will open in Xcode, ready for experimentation and testing! We’d love to know if this is a helpful feature, so be sure to [let us know on Twitter](https://twitter.com/SwiftPackages).

There’s also an amusing story behind this feature, which prompted us to write up the [story behind “The Button”](/posts/how-the-swift-package-index-project-got-started).
