We’re delighted to announce that we have added support for two new Swift platforms, Android and [Wasm](https://webassembly.org/), to our compatibility testing matrix.

<picture class="shadow">
  <source srcset="/images/blog/wasm-and-android-compatibility-matrix~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/blog/wasm-and-android-compatibility-matrix~light.png" alt="The Swift Package Index compatibility matrix showing columns for the Android and Wasm platforms.">
</picture>

Swift support for Wasm has been in development for [a long time](https://desiatov.com/swift-webassembly-2020/). Remarkably, [as of Swift 6.1](https://blog.swiftwasm.org/posts/6-1-released/) it requires no custom patches:

> This is the first stable release we've built directly from the official swiftlang/swift source without any custom patches. This means all components (compiler, stdlib, Foundation, XCTest, swift-testing, etc.) have been fully upstreamed.

There has also been plenty of community effort put into supporting Swift for Android. This includes the recent announcement of a [community working group](https://forums.swift.org/t/swift-on-android-working-group/77780) focused on the problem and the fact that [swift-everywhere.org](http://swift-everywhere.org) has been [tracking Android compatibility](https://skip.tools/blog/android-native-swift-packages/) for several months.

The community has put a remarkable amount of effort into getting these platforms to this stage, and it seemed like a great time to add them to our compatibility testing system. So we did!

As of today, all builds for both new platforms have finished and you can see compatibility on every package page.

### Results

After churning through X,XXX compatibility builds across both platforms for the past X days, we have some numbers to share! Of the ~9,000 currently indexed packages, **XX% build for Android** and **XX% build for Wasm**.

TODO: Add commentary on the results.

Is Windows compatibility testing next? We think so!
