We first launched support for package collections ahead of WWDC 2021 as a convenient way to add packages to an Xcode project.

The first release of this feature generated a package collection for all an author or organisation’s packages. For example, you can copy a link for the package collection for Apple’s packages via [their author page](https://swiftpackageindex.com/apple) and [add it to Xcode](https://swiftpackageindex.com/package-collections).

Human-curated collections are a logical next step, and we received a request to implement this from the SSWG. Today, we are adding the ability to create package collections for key community efforts.

### How does it work?

Custom collections work in a similar way to our package list. However, instead of adding a package to [packages.json](https://github.com/SwiftPackageIndex/PackageList/blob/main/packages.json), you add the location of a collection index file (whose contents _you_ maintain) to [custom-package-collections.json](https://github.com/SwiftPackageIndex/PackageList/blob/main/custom-package-collections.json).

[Here’s what this looks like](https://github.com/SwiftPackageIndex/PackageList/blob/6bc193c42d7b523a9159632b8fbe89e0c172316f/custom-package-collections.json#L2-L8), taking the Swift Server Workgroup Graduated packages as an example:

```
{
    "key": "sswg-graduated",
    "name": "Graduated",
    "description": "SSWG packages that are in 'graduated' state",
    "badge": "SSWG",
    "url": "https://swift.org/api/v1/sswg/incubation/graduated.json"
}
```

The fields in that JSON determine how we find and display the custom package collection.

The `key` field specifies the URL where the package collection will available on the Swift Package Index website:

<picture>
  <source srcset="/images/blog/custom-package-collection-url~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/blog/custom-package-collection-url~light.png" alt="Safari's Address Bar with the package collection URL in it highlighting the part of the URL related to the key field.">
</picture>

The `name` is its display name on the collections page as well as on the package page where we show a package’s membership to package collections:

<picture>
  <source srcset="/images/blog/custom-package-collections-package-page~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/blog/custom-package-collections-package-page~light.png" alt="The custom package collection badge highlighted on a package page.">
</picture>

The `description` field brielfly explains the motivation for this custom collection. It serves informational purposes and is not displayed.

The optional `badge` field is used to style the small badge next to the collection name on the package page. If omitted, the collection will have no badge.

Finally, the `url` field points to a location where you maintain a list of package URLs that belong to the collection. There should be of the format `https://github.com/author/package.git`. In particular, make sure the URL scheme is `https` and the `.git` suffix is included.

We match the listed packages against the list of all packages in the Swift Package Index and include only the ones we are able to match. Note that the matching is case-insensitive.

For example, here is the SSWG Graduated package collection’s list of packages:

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
