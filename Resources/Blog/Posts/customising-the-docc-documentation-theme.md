An interesting conversation on the [Swift Package Index Discord server](https://discord.gg/vQRb6KkYRw) this weekend led a group of us to dig into whether DocC’s support for customised themes worked with our [automatic package documentation hosting](https://swiftpackageindex.com/SwiftPackageIndex/SPIManifest/1.4.1/documentation/spimanifest/commonusecases) system.

The good news is that we do support it! We do very little processing of the generated DocC code after we build it, so we support everything that DocC generates.

This all came up as [Cihat Gündüz](https://github.com/Jeehut) wanted to customise the header for his [HandySwift package](https://swiftpackageindex.com/FlineDev/HandySwift). Here’s the result:

<picture class="shadow">
  <source srcset="/images/blog/handyswift-docc-custom-documentation-theme~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/blog/handyswift-docc-custom-documentation-theme~light.png" alt="The HandySwift documentation showing a customised theme with a gradient background and a logo image.">
</picture>

We think you’ll agree this is an improvement over the default look and feel. You can [check out the live version of this documentation on the site](https://swiftpackageindex.com/FlineDev/HandySwift/main/documentation/handyswift), and if you’d like to spruce up your package’s documentation, head over to the [DocC documentation on appearance customisation](https://www.swift.org/documentation/docc/customizing-the-appearance-of-your-documentation-pages) to learn how it’s done.

Drop us a note via [our Mastodon account](https://mas.to/@SwiftPackageIndex) if you take advantage of this theme customisation, and we’ll boost your reply.

**Note:** If you decide to customise the theme for your package’s documentation, the best way to test it out is *not* live on the SPI site. We coalesce commits from the default branch for a package and only build documentation a maximum of once every 24 hours. The best way to test theme customisation is to generate your web documentation locally with the [DocC preview command](https://apple.github.io/swift-docc-plugin/documentation/swiftdoccplugin/previewing-documentation/), get it looking how you like it locally, and *then* push it so we can build it for you.
