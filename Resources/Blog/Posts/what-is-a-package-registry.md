When we recently [announced that Swift Package Index was joining Apple](https://swiftpackageindex.com/blog/swift-package-index-joins-apple), you may have noticed one very significant line in that announcement post:

> Together, we’re building a comprehensive package registry to serve the Swift community’s evolving needs.

As we move towards that goal, we thought it would be worth revisiting what a package registry is and how you can use one today.

### What is a package registry?

There are three main parts of the Swift package tooling ecosystem. SwiftPM resolves your dependencies, fetching their source code so the compiler can build them. A package index (like [Swift Package Index](https://swiftpackageindex.com/)) helps you discover packages and learn what they do. A package registry *hosts and serves* the packages themselves. It’s the infrastructure that, when asked for version 1.0.2 of a specific package, serves back a verified, immutable archive of source code.

Most language ecosystems have a registry. JavaScript has [npm](https://www.npmjs.com/), Rust has [crates.io](https://crates.io/), Ruby has [RubyGems](https://rubygems.org/), and Python has [PyPI](https://pypi.org/).

### Depending on a Git-based package

You will probably be familiar with how that appears in a `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/swiftlang/swift-testing.git", from: "6.3.2")
]
```

During package resolution, SwiftPM clones Git-based dependencies from their source repository and checks out a matching tag. It then supplies the source code to the compiler, ready to build your app. This is simple and requires no extra infrastructure, but there are inherent disadvantages. Git checkouts can be slow and transfer more data than is needed. Git tags are also mutable, and while SwiftPM uses [Trust on First Use](https://en.wikipedia.org/wiki/Trust_on_first_use) (TOFU) checks that help mitigate that problem, TOFU only catches mutations that happen after first package resolution.

### Depending on a registry-based package

Here’s the same dependency import from a registry:

```swift
dependencies: [
    .package(id: "swiftlang.swift-testing", from: "6.3.2")
]
```

Package registries address the main downsides of Git-based dependencies. Package versions are immutable once published. A registry delivers source code in an archive without any Git history, which minimizes the download size. SwiftPM added [support for package registries](https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/PackageRegistry/PackageRegistryUsage.md) in Swift 5.7, so it’s available for use right now.

Fetching packages from a registry has several advantages, but some things don’t change:

* Your source code still lives wherever you choose to host it, be that GitHub, GitLab, or a self-hosted solution.
* Packages deliver source code, not pre-built binaries. You still compile your app’s code on your device.
* Git-based package resolution continues to work, and apps can mix registry dependencies and Git-based ones.

It’s worth noting that package registries also don’t create a walled garden. SwiftPM can register per-project registries, global registries, scope-specific registries, and anyone can implement a package registry for SwiftPM. There are already package registry implementations from [JFrog Artifactory](https://jfrog.com/integrations/swift-repository/), [AWS CodeArtifact](https://docs.aws.amazon.com/codeartifact/latest/ug/using-swift.html), [Cloudsmith](https://cloudsmith.com/product/formats/swift), and a community package cache hosted in the [Tuist registry](https://tuist.dev/en/docs/guides/features/registry).

### Walkthrough: Depending on a package from a registry

In this follow-along example, we will build a trivial SwiftPM-based command-line tool and switch the Swift Argument Parser dependency from Git-based to registry-based. We’ll use the Tuist registry here as a publicly available registry that has archived every package in the [Swift Package Index Package List](https://github.com/SwiftPackageIndex/PackageList/blob/main/packages.json).

**Step 1:** Create a “Hello, world!” package. Make a new directory and run:

```shell
swift package init --type tool --name TestPackage
```

**Step 2:** Add a registry to SwiftPM:

```shell
swift package-registry set https://tuist.dev/api/registry/swift
```

*Note: This command sets a default package registry for the current project, not [globally](https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/PackageRegistry/PackageRegistryUsage.md#configuring-a-registry).*

**Step 3:** Switch the dependency. Open the `Package.swift` file and make two changes. Switch the `dependencies` section to use [`package(id:from:)`](https://developer.apple.com/documentation/packagedescription/package/dependency/package(id:from:)) instead of [`package(url:from:)`](https://developer.apple.com/documentation/packagedescription/package/dependency/package(url:from:)):

```swift
dependencies: [
    .package(id: "apple.swift-argument-parser", from: "1.2.0")
]
```

Then switch the dependency’s reference in the `executableTarget`:

```swift
.executableTarget(
    name: "TestPackage",
    dependencies: [
      .product(name: "ArgumentParser", package: "apple.swift-argument-parser")
    ]
)
```

**Step 4:** Run the tool:

```shell
swift run
```

You’ll see SwiftPM resolve the package dependency using the registry, build the tool, and output “Hello, world!”. Congratulations, you just used a package registry!

If you’d like to learn more about how package registries work under the hood, the [SwiftPM documentation](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/usingswiftpackageregistry/) and the [Artifactory documentation](https://docs.jfrog.com/artifactory/docs/swift-repositories) are both good starting points.
