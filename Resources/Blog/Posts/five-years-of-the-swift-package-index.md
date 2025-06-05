When we launched the Swift Package Index five years ago, just before WWDC 2020, it covered 2,500 packages. Apple Silicon Macs didn’t exists yet (publicly, for another week 😅), we did not run compatibility builds, and did not generate or host documentation. visionOS was still years away and Swift didn’t cross-compile to Wasm and Android. Swift 5.2 was the latest language version and when Swift developers talked about actors over lunch it was understood the topic was the latest in film and TV.

With changes happening over such a long time – in terms of a software project – it is easy to overlook and take for granted all the incremental progress that has happened. And so today, on the eve of our five year anniversary, we would like to go on a little tour of our project and recap in numbers what an exciting journey it’s been.

Today, the site indexes over 9,000 packages, and package growth over the years has been remarkably consistent:

<picture class="shadow">
  <source srcset="/images/blog/number-of-packages~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/blog/number-of-packages~light.png" alt="A line chart showing the number of packages indexed growing from around 2,400 in June 2020 to over 9,000 today.">
</picture>

In 2022, we [launched automatic DocC documentation hosting](https://swiftpackageindex.com/blog/auto-generating-auto-hosting-and-auto-updating-docc-documentation), almost two years after the site launch. Since then, we’ve again seen incredible adoption of that feature and huge growth in package documentation. We now host documentation for over 1,100 packages, about 12% of _all_ packages:

<picture class="shadow">
  <source srcset="/images/blog/number-of-packages-with-documented-packages~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/blog/number-of-packages-with-documented-packages~light.png" alt="A line chart showing the number of documented packages overlaid on the previous chart, growing from 0 packages in June 2022 to over 1,100 today.">
</picture>

We can’t take _all_ the credit since DocC makes adding documentation to a package source code so easy, but we think [making it trivial](https://swiftpackageindex.com/SwiftPackageIndex/SPIManifest/documentation/spimanifest/commonusecases) to generate and host open source package documentation has helped.

Want some numbers? Let’s start with documentation. The storage for all that hosted documentation now totals 183GB across almost 30 million files! Those aren’t the only big numbers, though. Since we launched, we’ve processed almost 12 million builds, and are currently processing about 4 million builds per year for compatibility testing and documentation generation. We’ve also expanded the platforms we build for to a total of 8 now, including [adding two more last week](https://swiftpackageindex.com/blog/adding-wasm-and-android-compatibility-testing)! We even had a brief period where we were doing _both_ Intel and Apple silicon builds during the architecture transition we alluded to in the introduction. We’ve also tested compatibility with _every_ version of Swift since 4.2.

But all this data and these CPU cycles spent testing compatibility are useless if no one visits the site. 😬 Luckily, we’re doing fine, with over 600,000 Swift developers visiting the site every year.

Since we launched the index in 2020, at the height of the pandemic, it has come a long way. We added so much more metadata, README files, compatibility checking based on real builds, documentation hosting, a [podcast focused entirely on Swift packages](https://swiftpackageindexing.transistor.fm/), and much more. However, what’s most important to us is that we’ve become a site that the community uses every day.

Speaking of community, we’d love to thank _everyone_ who has contributed to the project over the years. That obviously includes [people who contributed code](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/graphs/contributors), but also if you opened an issue, started a discussion, or [joined us on our Discord](https://discord.gg/vQRb6KkYRw) to talk about the project.

A few days ago, we reached out to the community and asked if anyone had something they’d be happy having quoted in this blog post. Here’s what we got back:

> The Swift Package Index has grown into one of the largest open-source Swift projects. While companies like Amazon and Apple use Swift extensively behind closed doors, SPI stands out as arguably the largest public deployment of Swift on Server.

[Paul Hudson](https://www.hackingwithswift.com/) and [Mikaela Caron](https://mikaelacaron.com/) from [Swift over Coffee](https://podcasts.apple.com/us/podcast/swift-over-coffee/id1435076502)

<hr class="short" />

> The SPI makes it really easy to find packages when working with Swift on the Server, especially with the build matrix which makes it easy to see which packages work on Linux and what Swift versions are supported. The search is awesome! And being able to quickly find packages part of the SSWG incubation process is just an extra cherry on top!

[Tim Condon](https://www.timc.dev/)

<hr class="short" />

> The SPI and its role in the Swift Mentorship had a profound impact on me and completely changed how I view open source projects. _It was incredibly rewarding to collaborate with the team and_ be able to contribute to something that unites the community around our shared passion for Swift and contribute to a healthy dependency ecosystem. It was especially exciting to work using Swift on the Server. I’m thrilled to see the index continue to grow, and just like Dave once said, it’s a _living website_ that evolves with the Swift ecosystem.

[Javier Cuesta](https://github.com/jcubit)

<hr class="short" />

> I can’t tell you how grateful I am for Swift Package Index. It’s always been a great source to learn about all the cool stuff everyone is working on nowadays. It’s also a fantastic way for me to share what open source things I’m working on in the hopes they help someone else 🙂
>
> Thank you so much for creating it for our community!

[Adam Bell](https://www.adambell.ca/)

<hr class="short" />

> Swift Package Index has been a valuable asset to me and the community. As both a consumer and developer of packages, SPI provides robust features for an avid Swift developer like myself.

[Leo G Dion](http://brightdigit.com)

<hr class="short" />

> Swift Package Index has been incredibly helpful for discovering great Swift packages to use in my projects, especially when building Swift Playground apps on my iPad. Thanks for making it so easy to explore the Swift ecosystem!

[Ale Mohamad](https://alemohamad.com/)

<hr class="short" />

> SPI is an amazing tool for both library authors and users. It helps me make sure packages are in a good state.

[Joannis Orlandos](https://github.com/joannis)

<hr class="short" />

> Swift Package Index has been an absolute godsend for the Swift community. It’s been extremely helpful to see at a glance which platforms are supported for each package so I can figure out which ones to use as dependencies in my packages and projects.

[Christopher Jr Riley](https://bsky.app/profile/cjrriley.com)

<hr class="short" />

Thanks for everyone’s kind words, and here’s to another five years! 🚀
