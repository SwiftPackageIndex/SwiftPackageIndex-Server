---
date: 2022-10-17 12:00
title: Externally hosted package documentation
description: Using auto-hosted documentation remains the easiest way to get your package’s documentation available on the web, but we now also support documentation for projects that have more complex requirements or well-established documentation that already lives on the web.
---

> **UPDATE:** The information in this blog post is superceded by our [official documentation](https://swiftpackageindex.com/SwiftPackageIndex/SPIManifest/documentation/spimanifest/commonusecases). Please refer to the documentation rather than this blog post.

We have a little more documentation-related news to announce today!

We love that so many package authors have chosen to [host their package’s documentation with the Swift Package Index](https://blog.swiftpackageindex.com/posts/auto-generating-auto-hosting-and-auto-updating-docc-documentation/). There are now more than 180 packages that have opted in for us to host [versioned documentation](https://blog.swiftpackageindex.com/posts/versioned-docc-documentation/), and we think that’s excellent news for the Swift ecosystem.

Our hosted documentation generation is the easiest way to get DocC documentation hosted on the web, but some projects have more complex requirements or [well-established documentation websites](https://docs.vapor.codes/). So, we’re pleased to announce that the Swift Package Index now supports external documentation links!

If you’re a package author and would like to configure your package page to link to your external documentation, add or modify the `.spi.yml` file in your package’s repository root and tell us where to redirect visitors looking for documentation.

Here’s how to do it:

```
version: 1
external_links:
  documentation: "https://example.com/package/documentation/"
```

Here’s an [example](https://github.com/groue/GRDB.swift/blob/master/.spi.yml) from [GRDB](https://swiftpackageindex.com/groue/GRDB.swift), who already opted into this new feature.

In terms of what visitors to package pages see, it makes no difference where the documentation Lives. Visitors still see a single “Documentation” link in the package page sidebar.

We also created a universal documentation link for any package that has documentation either hosted by us or externally. For any package with documentation, navigate to:

```
https://swiftpackageindex.com/{owner}/{repository}/documentation
```

Replacing `{owner}` and `{repository}`, of course, and it will redirect to either our hosted or the external documentation.
