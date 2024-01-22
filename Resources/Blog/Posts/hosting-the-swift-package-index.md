---
date: 2021-03-30 12:00
title: Hosting the Swift Package Index
description: Making any open-source project sustainable for the long term is challenging in many ways, but with the Swift Package Index we also need significant hardware resources to keep it available.
---

![Logo images for the Swift Package Index, MacStadium, and Microsoft Azure](/images/hosted-by-macstadium-and-microsoft-azure.png)

Making any open-source project sustainable for the long term is challenging. You need to find time to work on the code, plan out features, respond to feedback, and if the project is not only code but a live web site, it also needs hosting and regular maintenance.

The Swift Package Index has slightly bigger hosting problems than most web sites, too. In addition to web and database servers, we need a significant amount of processing power to monitor and analyse constant package releases and run our build machines that deal with the ~30,000 Swift builds per month that process through our [compatibility build system](https://blog.swiftpackageindex.com/posts/launching-language-and-platform-package-compatibility/). 😅

We’re delighted to say that as of today, all of the Swift Package Index’s hosting problems are taken care of thanks to the generosity of two companies that believe in open-source.

First, [MacStadium](https://macstadium.com). The site has run on their Mac mini infrastructure since the [public launch](https://twitter.com/daveverwer/status/1271447550936186882) through their [open-source programme](https://www.macstadium.com/opensource). They have accommodated every request we have made, including giving us access to a DTK, which enabled [Apple silicon compatibility results](https://blog.swiftpackageindex.com/posts/building-3238-packages-for-apple-silicon/) months in advance of M1 machines becoming available. They are a pleasure to work with and consistently supportive. Thank you to Heather, Brian, and all of the support team at MacStadium.

However, while running the web hosting, the database, package update monitoring, Linux builders, and all the Apple builders all on the same hardware is possible, it’s not ideal. Our build queue had become quite delayed because we were asking those Mac minis to do too much.

That’s where [Microsoft Azure](https://azure.microsoft.com) stepped in. We have now eased the load by migrating our web hosting and Linux builders to Azure. The site is load balanced and redundant, which not only increases speed and availability, it also decreases the maintenance effort required. Working with Microsoft has been an absolute pleasure, and their only priority was to see the project succeed. Nothing was too much trouble. Thank you to Stormy, Thomas, Shelby, and Candice.

With the web servers, database, package update monitoring, and Linux builders hosted at Azure and the macOS, macOS ARM, iOS, tvOS, and watchOS builders at MacStadium, the hosting for this project is secure and stable for the foreseeable future. Thank you so much to both companies for their help. Running this site wouldn’t be possible without them.

**Note:** It’s worth mentioning that this blog post is not a condition of any agreement between us and either of these companies. All this support came without any expectation of anything other than enabling an open-source project. We are writing this purely because we are grateful for their help. ❤️
