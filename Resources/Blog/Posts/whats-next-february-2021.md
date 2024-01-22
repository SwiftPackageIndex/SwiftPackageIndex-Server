---
date: 2021-02-02 12:00
title: What’s Next? - February 2021
description: It’s been about seven months since we launched the Swift Package Index and we’ve been hard at work implementing a few major updates. Are we done? No, we are not!
---

It’s been about seven months since we [launched the Swift Package Index](https://iosdevweekly.com/issues/460#start) and we’ve been hard at work implementing a few major updates. Most significantly, [real-world package compatibility](https://blog.swiftpackageindex.com/posts/launching-language-and-platform-package-compatibility), [a comprehensive set of RSS feeds and Twitter updates](https://blog.swiftpackageindex.com/posts/keeping-up-to-date-with-swift-packages), and most recently [inline README files](https://blog.swiftpackageindex.com/posts/inline-readme-files).

But we’re far from done! 😅

So, in the spirit of letting you all know what we’re planning for this project next, we wanted to start a regular series of blog posts about the direction we’re heading with feature development. We’ll post every couple of months, giving a quick recap of what we’ve achieved along with where we’re heading next. It’s not a formal roadmap. It’s more a declaration of where our focus will be for the next couple of months.

So without further ado, what are we focusing on next?

## Intermediate Search Page

Currently, search results are displayed inline on the home page, which makes it hard to share package searches (there’s no URL for a search), or integrate with productivity tools like Alfred or Raycast, or even DuckDuckGo through their [bangs feature](https://duckduckgo.com/bang). We want to fix that.

## Package Collections

If you’ve been following the [package collection work](https://github.com/apple/swift-evolution/blob/main/proposals/0291-package-collections.md) in the SPM project, then it might have struck you that the Swift Package Index would be a great source of package collections, when they are added. We agree! We’ve already been working hard to prepare for this feature and want to have something publicly available as soon as the feature becomes available in SPM.

## Design updates

The site design suited our feature set at launch but has become a little overloaded as we added features. This work has already started, with a new package page layout rolling out last Friday. There’s more to do though, including improvements to the home page. The lists of recent package additions and recent package releases are fine, but we can do better!

## The Swift Package Index macOS App

We’ve always wanted to create a Swift Package Index Mac app of some kind. The app’s main purpose would be to allow you to easily try packages out in a Swift Playground (utilising the wonderful [Arena](https://swiftpackageindex.com/finestructure/Arena) tool). But it might end up being more over the long term. We want to define what this app will do, and then get something out that works towards that definition. We talked about the interesting story behind the “Try this package” feature [on John Sundell’s podcast last year](https://www.swiftbysundell.com/podcast/75/) if you’re interested!

## And More…

This is not a comprehensive list of things we’ll do. This is a young project, and we want to keep development agile. If we have a great idea, it may go into the plan ahead of everything you read above!

## Thank you!

We’d also like to use this update post to say a huge thank you to our generous sponsors. We wouldn’t be able to put in the time and effort needed by this project without the generous support of [Alexandre Colucci](https://github.com/Timac), [Artem Loenko](https://github.com/dive), [Bartosz Dolewski](https://github.com/bdolewski), [Boris Bügling](https://github.com/neonichu), [Byron Davies](https://github.com/welsh11), [Chris](https://github.com/csjones), [Dominik Hauser](https://github.com/dasdom), [Federico Zanetello](https://github.com/zntfdr), [Gleb Shevchenko](https://github.com/shgew), [James Sherlock](https://github.com/Sherlouk), [Jason Bruder](https://github.com/jabruder), [Jeffrey Macko](https://github.com/mackoj), [Joseph Heck](https://github.com/heckj), [Joshua Kaunert](https://github.com/jkaunert), [Juanpe Catalán](https://github.com/Juanpe), [Jules Coynel](https://github.com/jcoynel), [Kyle Lee](https://github.com/Kilo-Loco), [Leo Picado](https://github.com/leopic), [Marcos Griselli](https://github.com/marcosgriselli), [Massimo Biolcati](https://github.com/massimobio), [Matěj Kašpar Jirásek](https://github.com/mkj-is), [Max Desiatov](https://github.com/MaxDesiatov), [Nathan Harris](https://github.com/Mordil), [Oliver Drobnik](https://github.com/odrobnik), [PatrikTheDev](https://github.com/Patrik-svobodik), [Paul Farnell](https://github.com/paulfarnell), [Paul Hudson](https://github.com/twostraws), [Peter Steinberger](https://github.com/steipete), [PSPDFKit](https://github.com/PSPDFKit), [Riley Testut](https://github.com/rileytestut), [Robin Kunde](https://github.com/robinkunde), [Sam Symons](https://github.com/samsymons), [Scott Robbins](https://github.com/ScottRobbins), [Stefan-Cosmin Romanescu](https://github.com/StefanCosminR), [Thomas Dohmke](https://github.com/ashtom), [Tim Condon](https://github.com/0xTim), [Umar Haroon](https://github.com/Umar-M-Haroon), [Vadim Shpakovski](https://github.com/shpakovski), and [Xavier Lowmiller](https://github.com/xavierLowmiller). Thank you all! ❤️

Would you like to be part of this list next time we post an update like this? [Sponsoring the Swift Package Index](https://github.com/sponsors/SwiftPackageIndex) is done through GitHub Sponsors, and your support will allow us to continue to build this site into something special.
