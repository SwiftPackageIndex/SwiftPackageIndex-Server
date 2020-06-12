---
page-title: Add a Package
---

### Adding a package to the Swift Package Index

Adding a new package to the Swift Package Index is easy. This whole site is powered by a master list of repositories, stored in a JSON file (see [how does this site work](/faq#how-does-it-work) for more information).

To add a package to the site, just add a the URL of a publicly available git repository to [this JSON file](https://github.com/daveverwer/SwiftPMLibrary/blob/master/packages.json).

### Package requirements

Please feel free to submit your own, or other people's repositories to this list. There are a few requirements, but they are simple:

* The package repository must be publicly accessible.
* Packages must (obviously?) have a `Package.swift` file located in the root of the repository.
* Packages must be written in **Swift 4.0 or later**.
* Packages must declare at least one product in the `Package.swift` file. This can be either a library product, or an executable product. Packages can of course declare more than one product!
* Packages should have at least one release. A release is defined as a git tag that conforms to the [semantic version](https://semver.org) spec. This can be a [beta or a pre-release](https://semver.org/#spec-item-9) semantic version, it does not necessarily need to be stable.
* Packages should compile without errors. Actually, this isn't a strict requirement but it's probably a good idea since you're about to add the package to a package index!
* Packages must output valid JSON when `swift package dump-package` is run with the latest version of the Swift tools. Please check that you can execute this command in the root of the package directory before submitting.
* The full HTTPS clone URL for the repository should be submitted, including the .git extension.

**Note:** There's no gatekeeping or quality threshold to be included in this list. As long as the package is valid, and meets the above requirements

### How do you add a package?

It's simple. Fork this repository, edit `packages.json`, and submit a pull request. If you plan to submit a set of packages, there is no need to submit each package in a separate pull request. Feel free to bundle multiple updates at once as long as all packages match the criteria above.

Before submitting your pull request, please run the validation script locally:

```shell
swift ./validate.swift diff
```

Once validation is successul, please submit your pull request! Your package(s) will appear in the index within a few minutes.
