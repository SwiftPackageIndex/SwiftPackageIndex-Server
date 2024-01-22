---
date: 2023-04-24 12:00
title: Validating Swift Package Index Manifest Files
description: Swift Package Index Manifest files are YAML files that configure how the package index processes your package. With our online validator you can now confirm the format is correct without having to wait for reprocessing.
---

The Swift Package Index file `.spi.yml` file allows package authors to configure some aspects of how we process your package. This file has become much more popular since we [launched hosted documentation](/posts/versioned-docc-documentation).

Everyone’s favourite config file format YAML of course, comes without any sharp edges and so it is entirely superfluous that we’ve added an online validation tool where you can verify your manifests:

[SPI Manifest validation](https://swiftpackageindex.com/validate-spi-manifest)

We hope this helps package authors successfully set up their Swift Package Index manifests!

<picture>
  <source srcset="/images/spi-manifest-validation~dark.png" media="(prefers-color-scheme: dark)">
  <img src="/images/spi-manifest-validation~light.png" alt="The Swift Package Index manifest validation page.">
</picture>
