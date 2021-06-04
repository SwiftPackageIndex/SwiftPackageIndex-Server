---
page-title: Package Collections
description: The Swift Package Index supports the generation of package collections.
---

## Package Collections

Package Collections are a new feature in the Swift 5.5 release of the Swift Package Manager allowing packages to be grouped, searched, and have their metadata inspected.

The Swift Package Index supports dynamically generated Package Collections containing all packages from each author in the index. Every author page in the index includes a link to a [package collection](/vapor/collection.json). For example, from the [Vapor project's author page on the Swift Package Index](/vapor):

<picture class="shadow">
  <source srcset="/images/author-page-package-collection~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/author-page-package-collection~light.png" alt="Package Collection support on the Swift Package Index">
</picture>

To add this package collection to your Swift Package Manager, use the `swift package-collection add` command:

```
swift package-collection add https://swiftpackageindex.com/vapor/collection.json
```

> Note: If you see an error `unable to invoke subcommand` when running `swift package-collection`, ensure you have at least Swift 5.5 installed. You can check which version of Swift you're running with `swift --version`.

Then, to describe a package in that collection:

```
swift package-collection describe https://github.com/vapor/swift-argument-parser
```

The default output is plain text, but the command can output JSON if you add the `--json` parameter to the `describe` subcommand.

Finally, if you'd like to remove this package collection, call `swift package-collection remove`:

```
swift package-collection remove https://swiftpackageindex.com/vapor/collection.json
```
