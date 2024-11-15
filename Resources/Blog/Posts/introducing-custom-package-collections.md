We first launched support for package collections ahead of WWDC 2021 and they are a convenient way to add packages to an Xcode project.

We generate a package collection for all packages by an author or organisation. For example, you can copy a link for the package collection for all of Apple’s packages via [Apple’s author page](https://swiftpackageindex.com/apple) and add it to Xcode's package collections.

Since launching the feature we have been asked if we could support more curated collections that span multiple authors or organisations and today we are adding the ability to create package collections for key community efforts.

### How does it work?

The way this works is quite similar to adding packages to the Swift Package Index. Instead of adding a package to [packages.json](), you add a whole package list (whose contents _you_ maintain) to [custom-package-collections.json]().

Here’s what this looks like, taking the Swift Server Workgroup Graduated packages as an example:

```
{
    "key": "sswg-graduated",
    "name": "SSWG Graduated",
    "description": "SSWG packages that are in 'graduated' state",
    "url": "https://raw.githubusercontent.com/finestructure/sswg-package-lists/refs/heads/main/graduated.json"
}
```

The `key` field essentially determines the URL at which the package collection is available on the Swift Package Index:

    [https://swiftpackageindex.com/collections/sswg-graduated](https://swiftpackageindex.com/collections/sswg-graduated)

The `name` is its display name on the collections page as well as on the package page where we show a package’s membership to package collections:

TODO: update image with new badge icon

<picture>
  <source srcset="/images/blog/custom-collections-package-page.png" media="(prefers-color-scheme: dark)">
  <img src="/images/blog/custom-collections-package-page-light.png" alt="Screenshot of the custom collection badge on a package page.">
</picture>

The `description` field brielfly explains the motivation for this custom collection. It serves informational purposes and is not displayed.

TODO: describe `badge` attribute.

Finally, the `url` field points to a location where you maintain a list of package URLs that belong to the collection. There should be of the format `https://github.com/author/package.git`. In particular, make sure the URL scheme is `https` and the `.git` suffix is included.

We match the listed packages against the list of all packages in the Swift Package Index and include only the ones we are able to match. Note that the matching is case-insensitive.

For example, here is what the SSWG Graduated package collection’s content looks like:

```
[
  "https://github.com/apple/swift-crypto.git",
  "https://github.com/apple/swift-log.git",
  "https://github.com/apple/swift-metrics.git",
  "https://github.com/apple/swift-nio.git",
  "https://github.com/apple/swift-statsd-client.git",
  "https://github.com/grpc/grpc-swift.git",
  "https://github.com/swift-server-community/APNSwift.git",
  "https://github.com/swift-server/async-http-client.git",
  "https://github.com/vapor/jwt-kit.git",
  "https://github.com/vapor/multipart-kit.git",
  "https://github.com/vapor/postgres-nio.git",
  "https://github.com/vapor/vapor.git",
]
```

### How to propose new custom collections

We will be considering additions to the custom collections list on a case by case basis for package lists that benefit the Swift package ecosystem.

Such lists should be goverened by a group or organisation active in the Swift open source community and have appeal for a significant part of the Swift ecosystem.

The intial set of SSWG collections give an example of these requirements:

- The content of the lists is managed by the Swift Server Workgroup.
- While mainly geared towards server-side development, many packages like for example `swift-crypto` are relevant even for developers not working with server-side Swift.
- Making the maturity levels of these packages visible on the Swift Package Index helps developers find quality packages for their needs.

Please [get in touch](https://discord.gg/vQRb6KkYRw) if you have questions, would like to propose a new custom collection, or open an issue or pull request on the [PackageList repository](https://github.com/SwiftPackageIndex/PackageList/) for discussion.
