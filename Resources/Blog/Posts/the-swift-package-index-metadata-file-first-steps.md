---
date: 2020-10-30 12:00
title: The Swift Package Index Metadata File – First Steps
description: The Swift Package Index gathers most of the metadata about a package from external sources. The package manifest, the git repository, and GitHub. But, there are some things we need to know that are specific to the Swift Package Index. Learn how to take advantage of the extra settings available to your package.
---

The vast majority of the information you see in [the package index][1] is generated from a single URL, the location of the package’s git repository.

From that URL we gather data from the repository itself, the package manifest, the GitHub API (yes, it’s GitHub only for now, but [we do plan to support other hosts][2]), and from running builds of the package to check compatibility with operating systems and Swift versions.

## Edge cases

Of course, as with everything in software development, it’s not long before you find yourself talking about edge cases.

While creating [the build system][3], we quickly encountered packages where watchOS targets failed to build. We use Xcode’s automatic scheme creation functionality while running builds, but Xcode generates schemes that always include test targets, and `XCTest` isn’t available on watchOS. Using automatic schemes for watchOS builds wasn’t going to work.

The only way to have these builds succeed is for our build system to use a specific scheme, rather than an automatically created one. Many packages already have schemes for this purpose, but as package authors can give schemes any name, it’s not possible to easily discover them.

## Enter the Swift Package Index configuration file

Rather than trying to keep the build system 100% generic, we needed a mechanism for package authors to specify some configuration information, such as the scheme name to use to build watchOS targets.

We support this via a configuration file, `.spi.yml` which we will look for in the root of your Swift package repository.

### Schemes for watchOS

You can see the popular package [`swift-composable-architecture`][4] by [Pointfree][5] making use of [this config file][6]:

```yaml
version: 1
builder:
  configs:
  - platform: watchos
    scheme: ComposableArchitecture_watchOS
```

Our build servers look for this file and use any scheme information we find for each platform. If a platform isn’t listed, we use our default heuristics to determine the scheme as outlined in our [build FAQ][7].

### Images for Linux

Custom schemes aren’t all we support though. Package authors can also use the `.spi.yml` file to configure custom docker base images for our Linux builds.

We build packages for Linux with docker commands, selecting between the [various base images that Apple provide][8].

```bash
/usr/local/bin/docker run --rm -v "$PWD":/host -w /host swiftlang/swift:5.2.4 swift build --enable-test-discovery
```

This works well unless a package requires an OS-level dependency, like OpenSSL.

We may eventually provide our own set of base images for supported Swift versions that also include common dependencies like OpenSSL. For now, we are asking package authors whose builds fail due to missing dependencies to create their own for the Swift versions they support.

For security reasons, we don’t allow package authors to specify arbitrary images in the configuration file, so if you need to use this feature, please [raise an issue asking for us to support a custom base image][9].

The AWS library [Soto][10] is an example of a package that makes use of this feature in its [`.spi.yml` file][11]:

```yaml
version: 1
builder:
  configs:
  - platform: linux
    swift_version: '5.0'
    image: adamfowlerphoto/aws-sdk-swift:5.0
  - platform: linux
    swift_version: '5.1'
    image: adamfowlerphoto/aws-sdk-swift:5.1
  - platform: linux
    swift_version: '5.2'
    image: adamfowlerphoto/aws-sdk-swift:5.2
  - platform: linux
    swift_version: '5.3'
    image: adamfowlerphoto/aws-sdk-swift:5.3
```

## Future direction

It’s early days for this configuration file. We created it to solve issues which package authors were facing trying to make sure that the language and platform compatibility we report reflects reality.

We expect this file to evolve, which is why it carries a version number. Here are some of the things we are planning to add over time, so that package authors can control them:

- Author metadata. Full name, blog URL, Twitter account, etc.
- Package keywords or categories.
- The location of any hosted documentation for a package.
- Sponsorship or funding information for a package.

More metadata possibilities are under discussion in [this GitHub issue][12]. This is a great place to chime in if you have suggestions.

## File format

We chose `YAML` as the file format because it is an uncontroversial, universally beloved format that is entirely [free of issues][13]. 😬

Seriously though, we chose YAML as it’s relatively easy for a human to read and write, and it’s well supported in Swift. While it has some downsides compared to JSON, we believe it’s a more practical format given that package authors need to create this file manually.

Of course, we’ll let adoption be the guide as to how well it is working in practice!

[1]: https://swiftpackageindex.com
[2]: https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/485
[3]: /posts/launching-language-and-platform-package-compatibility
[4]: https://github.com/pointfreeco/swift-composable-architecture
[5]: https://www.pointfree.co
[6]: https://github.com/pointfreeco/swift-composable-architecture/blob/main/.spi.yml
[7]: https://swiftpackageindex.com/docs/builds#built-how
[8]: https://hub.docker.com/r/swiftlang/swift
[9]: https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/new
[10]: https://swiftpackageindex.com/soto-project/soto
[11]: https://github.com/soto-project/soto/blob/main/.spi.yml
[12]: https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/435
[13]: https://www.arp242.net/yaml-config.html
