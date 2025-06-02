We’re delighted to announce support for compatibility testing of packages on two new Swift platforms, Android and [Wasm](https://webassembly.org/). This brings the number of platforms we test every package with to 8!

<picture class="shadow">
  <source srcset="/images/blog/wasm-and-android-compatibility-matrix~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/blog/wasm-and-android-compatibility-matrix~light.png" alt="The Swift Package Index compatibility matrix showing columns for the Android and Wasm platforms.">
</picture>

Swift support for Wasm has been in development for [a long time](https://desiatov.com/swift-webassembly-2020/), and [as of Swift 6.1](https://blog.swiftwasm.org/posts/6-1-released/), it now requires no custom patches:

> This is the first stable release we’ve built directly from the official swiftlang/swift source without any custom patches. This means all components (compiler, stdlib, Foundation, XCTest, swift-testing, etc.) have been fully upstreamed.

Swift on Android is also receiving plenty of community effort, including a recent announcement of a [community working group](https://forums.swift.org/t/swift-on-android-working-group/77780). The [swift-everywhere.org](http://swift-everywhere.org) site has also been [tracking Android compatibility](https://skip.tools/blog/android-native-swift-packages/) for several months.

Plenty of work went into making Swift work on these platforms, and it seemed like a great time to add them to our compatibility testing. So we did! For the past week, the Swift Package Index build system has processed 35,000 builds to test compatibility. As of today, all builds are complete, and you can see Wasm and Android compatibility on every package page.

### Results

Of ~9,000 indexed packages, **18.9% build for Wasm** and **27.9% build for Android**. We find that remarkable, given that reliance on Apple-specific frameworks automatically makes many packages incompatible.

It’s safe to say that Swift is expanding beyond its Apple-focused roots. Windows and Linux have been officially supported for years, and Wasm and Android are starting to make their way down that path. It’s great to see.
