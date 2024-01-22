---
date: 2021-05-05 12:00
title: How the Swift Package Index project got started because of a button
description: How did the Swift Package Index project get started, and why does a button feature so prominently in the story? Read on to find out.
---

It’s been [one year since we made the first commit](https://twitter.com/_sa_s/status/1386033811348197380) on the [Swift Package Index repository](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server), and we think that deserves a little celebration!

<center style="font-size: 30px;">🎂</center>

Did you enjoy the cake? 😂 No? Well, how about we also tell you the story of how this project started?

**Note:** We usually write blog posts here in the first person plural as this project is very much a joint effort, but this is a story with lots of references to both [Dave](https://twitter.com/daveverwer) and [Sven](https://twitter.com/_sa_s) individually, so I’ll write it in the first person singular. _Dave_

Before the Swift Package Index, there was the [SwiftPM Library](https://daveverwer.com/blog/launching-the-swiftpm-library/). The goal of that site was the same as this one, to provide a comprehensive index of Swift packages that helps you make better decisions about your dependencies.

A little while after the launch, I had a message from some members of the [Vapor Discord](https://discord.com/invite/vapor). They had been chatting about creating something similar as an open-source Swift/Vapor project and wondered if I might be interested in collaborating on it. I’ll admit that I wasn’t hugely excited about rewriting a site that I had just launched, but I was in favour of it becoming open-source. However, the reality of an open-source project focused on indexing Swift packages being a Ruby project would make finding contributors challenging, so I put aside my doubts and decided to go for it. I started learning Vapor and got started. Unfortunately, circumstances worked against the rewrite being a success at that point. I found the Vapor learning curve tough while also maintaining the existing site, and the folks from the Vapor Discord were busy too. The project started to progress, but slowly.

That’s when I got an email from Sven. He had seen the SwiftPM Library and wondered if I might be open to integrating his open-source project, [Arena](https://github.com/finestructure/Arena), with it. His idea was to add a button next to each search result that, when clicked, would create a Swift Playground that imported the library, ready for experimentation. It was a great idea, and we ended up on a quick audio call a few days later to discuss it. While we chatted, I mentioned the potential rewrite of the SwiftPM Library into Swift/Vapor, and it turned into a much larger conversation. Sven was interested in the project, experienced working with Vapor, and keen to help. A winning combination! 🥇

Things progressed very quickly after that. I wrote up some details of how the existing project worked, and Sven worked his Vapor magic. Before too long, we had a prototype up and running, and the project started to feel real. There wasn’t time to add “the Arena button” as we needed to get the basics implemented first, but it remained firmly on the to-do list.

Sven and I ended up working really well together. We had different, complementary skill sets, and we progressed quickly towards getting the new project finished. It had been open-source from day one, and we were working in public, but no one had noticed, and we started to gear up for the [launch of the Swift Package Index](https://iosdevweekly.com/issues/460#start).

There was still no sign of “the button”, though, even many months after the launch. 😬

It wasn’t through any malice or deliberate neglect. It was just that there was always something else that took a slightly higher priority. We worked on [language and platform compatibility reporting](/posts/launching-language-and-platform-package-compatibility), [Apple silicon builds](/posts/building-3238-packages-for-apple-silicon), [gathering additional metadata](/posts/the-swift-package-index-metadata-file-first-steps), [funding the project](/posts/funding-the-future-of-the-swift-package-index), [RSS feeds](/posts/keeping-up-to-date-with-swift-packages), [inline README files](/posts/inline-readme-files), [finding suitable hosting](/posts/hosting-the-swift-package-index), and [many more things](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/pulls?q=is%3Apr+is%3Aclosed) that didn’t make it to the blog.

I’m delighted to say that today sees the launch of “the button”! But what does the button do? Read more about that in the [official launch post](/posts/launching-the-swift-package-index-playgrounds-app-for-macos).

That deserves more than a cake! 🥂🍾

I’m happy that we **finally** got to bring Sven’s original idea to fruition through this project, but this celebration is about much more than that! Working with Sven on this project has been a pleasure from the beginning. We work incredibly well together and are making something that feels significant and important. The button is part of that, but the potential of the site is so much more.

It’s also worth mentioning that if you want to hear Sven and I talk about this story in person, we [discussed it on John Sundell’s podcast](https://swiftbysundell.com/podcast/75/) last year.

Here’s to year two!
