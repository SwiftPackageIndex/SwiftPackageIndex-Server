---
page-title: Builds FAQ
description: Frequently Asked Questions about the Build System
---

## The SPI Build System FAQ

* [Why doesn’t my package show any builds?](#no-builds)
* [What revision is the default branch built for?](#what-revision)
* [How is my package being built?](#built-how)
* [When was it last built?](#last-built)
* [How long until builds are done after a new release/commit on default branch?](#how-long)
* [How can I hide failing builds for platforms I don’t support?](#hide-failing-builds)
* [The build is shown as failed but I know my package supports this platform, what do I do to fix it?](#fix-false-negative)
* [The build shows an error that doesn’t seem to have anything to do with a build error. How can I fix this?](#unrelated-error)
* [I’ve fixed a build, how do I trigger a re-run?](#trigger-rebuild)

<h3 id="no-builds">Why doesn’t my package show any builds?</h3>

The Swift Package Index picks up new default branch revisions and releases automatically. However, it can take a little while for it to do so. New builds should appear within a few hours after a revision change.

If you see a little clock symbol, your builds are on their way in the build queue and should appear shortly.

<h3 id="what-revision">What revision is the default branch built for?</h3>

The Swift Package Index does not currently display which default branch revision has been built. If your default branch revision changed more than a few hours ago it is very likely the revision that has been built. It is best to rely on (pre-)releases to for precise Swift version and platform compatibility.

<h3 id="built-how">How is my package being built?</h3>

We run `xcodebuild` and/or `swift build` (as applicable) for the platform and the specified Swift versions.

For `xcodebuild` we apply some heuristics to find the correct scheme to build. If your package contains a single scheme (as reported by `xcodebuild -list`) we will build that scheme.

If `xcodebuild -list` reports multiple schemes, we build the one ending in `-Package`. Otherwise we try removing existing Xcode project and workspace files and rely on SPM’s scheme discovery to autogenerate a package scheme for building.

<h3 id="last-built">When was it last built?</h3>

The Swift Package Index does not currently display when a revision has been built. You can assume this to have happened a few hours after a revision change.

<h3 id="how-long">How long until builds are done after a new release/commit on default branch?</h3>

New revisions are typically built within a few hours.

<h3 id="hide-failing-builds">How can I hide failing builds for platforms I don’t support?</h3>

This is currently not possible. By displaying a grey cross in the compatibility matrix we aim to show this is a lack of platform or Swift version support and not a failure per se. However, on the build details page we show these with red crosses to make it easier for the package maintainer to find and inspect what may be genuine build problems.

<h3 id="fix-false-negative">The build is shown as failed but I know my package supports this platform, what do I do to fix it?</h3>

First, please try to replicate the build locally with the build command we show on the build details page. This may help reveal if there is some issue with the package set up or our way of discovering the build scheme.

If this is something you can correct, great! Simply make the change and we will re-process your builds.

If this is not possible, please get in touch so we can improve our build command and make it work with your package.

<h3 id="unrelated-error">The build shows an error that doesn’t seem to have anything to do with a build error. How can I fix this?</h3>

In some cases we may have encountered build issues unrelated to your package. Please confirm using the build command we show on the build page whether you can build your package successfully for a given Swift version and platform.

If this succeeds, please let us know so we can remove the faulty builds and schedule a rebuild.

<h3 id="trigger-rebuild">I’ve fixed a build, how do I trigger a re-run?</h3>

Simply commit a change to your default branch or make a new (pre-)release. In a few hours the Swift Package Index will revisit your package and rebuilt the new revision.
