---
page-title: Package Collections
description: The Swift Package Index supports the generation of package collections.
---

## Package Collections

[Added in Swift 5.5](https://swift.org/blog/package-collections/), package collections are a way to group and search Swift packages. You can add collections into Xcode 13, giving you a much easier way to add your favourite or commonly used packages into your apps.

The Swift Package Index dynamically generates package collections containing all packages from every package author in the index. Each author page includes a "Copy Package Collection URL" button that copies a link you can directly paste into Xcode. For example, from the [Vapor project's author page on the Swift Package Index](/vapor):

<picture class="shadow">
  <source srcset="/images/screenshots/author-page-vapor-packages~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/screenshots/author-page-vapor-packages~light.png" alt="Package Collection support on the Swift Package Index.">
</picture>

### Using Package Collections with Xcode 13

Select your project in the Xcode project navigator, select it again in the projects and targets list, and switch to the Swift Packages tab:

<picture>
  <source srcset="/images/screenshots/xcode-13-swift-packages-tab~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/screenshots/xcode-13-swift-packages-tab~light.png" alt="Xcode 13 showing the Swift Packages tab.">
</picture>

Click the `+` button below the Packages list, and you'll see a Collections list on the left and details about the packages in each collection on the right.

<picture>
  <source srcset="/images/screenshots/xcode-13-package-collections~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/screenshots/xcode-13-package-collections~light.png" alt="Xcode 13 showing the package collection manager.">
</picture>

Click the `+` at the bottom of the Collections list and paste in the URL to a package collection. That's it! You can now add packages from that collection to your project by selecting one and clicking "Add Package".

> **Note:** When adding a package collection from the Swift Package Index, you'll see a warning "Package Collection Not Signed". We're working on adding support for signed collections.

### Using Package Collections with the Swift Package Manager

To add a package collection using the `swift` command-line tool, use the `swift package-collection add` command:

```
swift package-collection add https://swiftpackageindex.com/vapor/collection.json
```

> **Note:** If you see an error `unable to invoke subcommand` when running `swift package-collection`, ensure you have at least Swift 5.5 installed. You can check which version of Swift you're running with `swift --version`.

Then, to describe a package, use the `swift package-collection describe` command:

```
swift package-collection describe https://github.com/vapor/vapor
```

The default output is plain text, but the command can output JSON if you add the `--json` parameter to the `describe` subcommand.

Finally, to remove a package collection, call `swift package-collection remove`:

```
swift package-collection remove https://swiftpackageindex.com/vapor/collection.json
```

For more information about package collections, [see the documentation](https://github.com/apple/swift-package-manager/blob/main/Documentation/PackageCollections.md).
