---
date: 2024-01-18 12:00
title: Highlighting package funding links
description:
---

The story is as old as time, or at least as old as [`time_t`](https://www.gnu.org/software/libc/manual/html_node/Time-Types.html)! A kind developer writes some code and makes it open-source as a library, hoping it might help others. Over time, that library might gain popularity, prompting other developers to raise issues, open discussions, and sometimes even pull requests! However, it can also happen that the original developer realises they are spending all their free time working for free on a project they might not even use anymore, leading to burnout and many abandoned projects.

Are services like [GitHub Sponsors](https://github.com/sponsors), [Open Collective](https://opencollective.com/), [Patreon](https://www.patreon.com), and [Ko-fi](https://ko-fi.com) the answer? We’re not convinced they are a perfect solution, but they are the best “one size fits all” solution we have.

It was pointed out to us recently that while package pages contain more Swift-specific metadata and other useful information, they hide the sponsorship links shown on the GitHub repository page. This feature was on our list of things we’d like to add, but we hadn’t got around to it.

We’re happy to say that we now have got around to it! You’ll see links to any funding platforms directly underneath package metadata.

<picture>
  <source srcset="/images/package-funding-cta~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/package-funding-cta~light.png" alt="Package funding links for the Vapor package on Swift Package Index.">
</picture>

Adding this feature also made us curious about how many open-source packages are seeking funding, so we did a little digging through the data, and there are 256 individuals or organisations accepting funding for 718 packages. That’s more than 10% of all packages in the index!

The only difficulty with this feature is that browsing for a new package isn’t the right time to decide to sponsor it. However, we would encourage you to look through your project’s _used_ dependencies and then return to their package pages to see if any are seeking funding.
