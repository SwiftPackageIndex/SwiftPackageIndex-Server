---
date: 2022-01-25 12:00
title: Keeping up with dependency changes
description: How often do you update your package dependencies, and when you do, do you check what’s new or changed? We have a new tool that can help!
---

How often do you update your package dependencies, and when you do, do you check what’s new or changed, or do you just run your tests to check nothing broke and move on? 😅

Don’t be embarrassed. You’re not alone! Even if the package authors have lovingly crafted a detailed change log, checking them for every package you use is painful. It’s no wonder no one takes the time to do it.

So we built a little tool to make the task easier. Install the [swift-release-notes](https://swiftpackageindex.com/SwiftPackageIndex/ReleaseNotes) tool, and get a list of links to the release notes for all the packages that have pending updates.

```shell
$ swift release-notes ~/Projects/SPI/spi-server

(... progress output removed)

Release notes URLs (updating from):
https://github.com/vapor/fluent-kit/releases (1.19.0)
https://github.com/apple/swift-llbuild/releases (main)
https://github.com/vapor/vapor/releases (4.54.0)
https://github.com/apple/swift-package-manager/releases (main)
https://github.com/vapor/async-kit/releases (1.11.0)
https://github.com/apple/swift-nio-ssl/releases (2.17.1)
https://github.com/apple/swift-tools-support-core/releases (main)
https://github.com/apple/swift-nio-transport-services/releases (1.11.3)
https://github.com/apple/swift-driver/releases (main)
https://github.com/apple/swift-nio/releases (2.36.0)
```

Give it a try and be better aware of what new changes are happening in the packages you’re using!
