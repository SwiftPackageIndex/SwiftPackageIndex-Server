---
page-title: Builds FAQ
description: Frequently Asked Questions about the Swift Package Index Build System
---

## The Swift Package Index Build System

- [What is the Swift Package Index Build System?](#build-system)
- [Why does a package show missing or incomplete compatibility?](#no-builds)
- [What revision is the default branch built for?](#what-revision)
- [How are packages built?](#built-how)
- [How does the build system build with different Swift versions?](#swift-versions)
- [When was a package last built?](#last-built)
- [Is it possible to hide failing builds for unsupported platforms?](#hide-failing-builds)
- [If a build is showing failed incorrectly, how can I fix it?](#fix-false-negative)
- [If a build is showing an error that seems unrelated to the build, how can I fix it?](#unrelated-error)
- [How can I diagnose problems where dependencies can't be resolved?](#dependency-resolving-error)
- [What is data race safety and how is it tested?](#data-race-safety)

<h3 id="build-system">What is the Swift Package Index Build System?</h3>

The Swift Package Index bases its Swift version and platform compatibility data on real-world results from our build system. The build system supports all Apple platforms (iOS, macOS, watchOS, tvOS ) and Linux, giving comprehensive, proven, real-world compatibility information.

The Swift Package Index polls every package for changes and new releases constantly. Whenever it sees changes, it compiles the code across a comprehensive set of Swift versions and platforms. For example, check out the [package compatibility report](https://swiftpackageindex.com/SnapKit/SnapKit/builds) for [SnapKit](https://swiftpackageindex.com/SnapKit/SnapKit).

**Note:** The build system checks compatibility for every release, no matter how frequent, whereas the system builds the default branch for a package at most every 24-hours. If there are updates to a default branch during the same day, new compatibility checks start once the 24-hour timeout expires.

<h3 id="no-builds">Why does a package show missing or incomplete compatibility?</h3>

The Swift Package Index will pick up new default branch revisions and releases automatically. It can take a little while for build results to become available after a commit or new version release though, so if the compatibility matrix shows a clock symbol then builds are still pending, and results are on their way!

<h3 id="what-revision">What revision is the default branch built for?</h3>

The Swift Package Index does not currently display which revision the default branch tracks. If a default branch revision changed more than a few hours ago, everything should be up to date. If there looks to be a problem with a build not updating after several hours, please [raise an issue](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/new/choose).

<h3 id="built-how">How are packages built?</h3>

The build system runs either `xcodebuild` or `swift build` depending on the platform and specified Swift versions.

When running `xcodebuild`, we apply some heuristics to find the correct scheme to build. If a package contains a single scheme (as reported by `xcodebuild -list`), the build system will use that scheme. If `xcodebuild -list` reports multiple schemes, the build system will choose the one ending in `-Package`. Otherwise, it will try removing any Xcode project and workspace files and rely on SPM’s scheme discovery to autogenerate a package scheme.

<h3 id="swift-versions">How does the build system build with different Swift versions?</h3>

The build system aims to reproduce a real-world environment for building packages as much as possible. Ideally, if the Swift Package Index says it's compatible with Swift 5.1 and your project uses Swift 5.1, it should work. The most real-world way for us to build is to use multiple different versions of Xcode to process each package. We use the latest available version of Xcode that shipped with the release of Swift that we want to compile with as default.

In order to find out which Xcode version a Swift version corresponds to, please refer to [swiftversion.net](https://swiftversion.net). We also show this as part of the build command on the details page of each individual build.

The build system uses the `DEVELOPER_DIR` environment variable to switch versions of Xcode. This applies to both `xcodebuild` and `swift build` commands.

<h3 id="last-built">When was a package last built?</h3>

The Swift Package Index does not currently display the date/time of the last build for a package, but everything is typically up to date a few hours after a revision or version release.

<h3 id="hide-failing-builds">Is it possible to hide failing builds for unsupported platforms?</h3>

Not currently. However, by using grey rather than red for the compatibility matrix, we aim to show this is a lack of platform or Swift version support rather than a failure per se. On the build details page, we show statuses with red crosses to make it easier for the package maintainer to find and inspect what may be genuine problems.

<h3 id="fix-false-negative">If a build is showing failed incorrectly, how can I fix it?</h3>

As a package author, you might think that a package should be compatible with a platform or Swift version, where the Swift Package Index shows it as incompatible. First, please try to replicate the build locally with the build command that the build system uses. The build details page shows the full build command which will help reveal if there is some issue with the package set up or our way of discovering the build scheme.

If you can fix the problem, great! Fix the issue, push the change, and we will re-process your builds. If the problem is more serious, please [raise an issue](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/new/choose) so we can improve the build system.

<h3 id="unrelated-error">If a build is showing an error that seems unrelated to the build, how can I fix it?</h3>

In some cases, we may have encountered build issues unrelated to your package. Please confirm using the build command shown on the build details page that you can build your package successfully for a given Swift version and platform. If this succeeds, please [raise an issue](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/new/choose) so we can remove the faulty builds and schedule a rebuild.

<h3 id="dependency-resolving-error">How can I diagnose problems where dependencies can't be resolved?</h3>

If you encounter the following error on the build details page:

```
xcodebuild: error: Could not resolve package dependencies:
unknown package 'foo' in dependencies of target 'Bar'; valid packages are: 'baz', 'baq'
```

The likely cause is a local package dependency (for instance, an example project that imports the package) with the package dependency declared as:

```
.package(path: "../../")
```

In cases like this, Xcode cannot resolve package dependencies because of how it guesses package names. To fix this, specify the package name in your dependency clause, like so:

```
.package(name: "foo", path: "../../")
```

You can [find more details in this issue](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1532).

<h3 id="data-race-safety">What is data race safety and how is it tested?</h3>

The Swift 6.0 compiler can check whether code is safe from data races at compile time when strict concurrency checks are enabled. The data race safety information we publish on package pages comes from metadata output by the compiler during our build process.

Note that this does not affect package compatibility as shown in the compatibility matrix. A package can be fully compatible with Swift 6.x without opting into struct concurrency mode provided it is not running in Swift 6 language mode. For more information on opting into Swift 6 language mode, [read this for more information](https://www.swift.org/documentation/concurrency/).
