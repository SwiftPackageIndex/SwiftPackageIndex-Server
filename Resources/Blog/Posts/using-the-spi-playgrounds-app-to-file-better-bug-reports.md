---
date: 2021-05-17 12:00
title: Using the SPI Playgrounds app to file better bug reports
description: If you've been wondering why we created the SPI Playgrounds app, read on for a story where we used a playground to file a better bug report in the Vapor project.
---

We [recently released the SPI Playgrounds app](/posts/launching-the-swift-package-index-playgrounds-app-for-macos), which allows you to try out Swift Packages in a Playground in Xcode. You can use it to quickly get up and running with a new package when evaluating dependencies. However, it can also be helpful when working with dependencies you _already_ use in your project. One such use case is creating reproducible bug reports.

It’s often tricky for open-source maintainers to help people when they report issues, especially if they are in a large app, where reproducing a bug might require a significant amount of set-up. It can be especially challenging for Swift on the server projects, where you might have dependencies like databases and other services.

To help open-source maintainers to help you, it can be useful to prepare something they can run in a standalone way. How about in a playground? It doesn’t get much simpler than that!

Recently, looking at [one of the issues](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1015) in the [Swift Package Index](https://swiftpackageindex.com), it turned out that this was the perfect opportunity to use [Arena](https://github.com:finestructure/Arena) to create a playground where we could reproduce the issue.

**Note:** Arena is the underlying tool used in the [SPI Playgrounds app](https://swiftpackageindex.com/try-in-a-playground/). Think of it as the command-line version of the app. We’re using it here as it allows you to create a Playground with more than one dependency embedded, which the SPI Playgrounds app doesn’t yet support.

We started by running Arena as follows:

```bash
arena https://github.com/vapor/vapor https://github.com/vapor/fluent https://github.com/vapor/fluent-postgres-driver -o ssl-error-repro
```

This command produced a playground which imported Vapor, Fluent, and the Postgres driver. We knew the issue happened when accessing an Azure Postgres database via TLS, so we set up a test database with a single record and read the record via Fluent.

The whole snippet to reproduce the bug was about 30 lines:

```swift
import Vapor
import Fluent
import FluentPostgresDriver

final class Test: Model, Content {
    static let schema = "test"

    @ID(key: .id)
    var id: UUID?
}

func run() throws {
    let app = Application(.testing)
    defer { app.shutdown() }

    let tlsConfig: TLSConfiguration = .forClient()
    app.databases.use(.postgres(hostname: "pgnio-debug.postgres.database.azure.com",
                                port: 5432,
                                username: "test@pgnio-debug",
                                password: "<ask me for the password>",
                                database: "test",
                                tlsConfiguration: tlsConfig), as: .psql)

    let db = app.db

    let t = try Test.find(UUID("cafecafe-cafe-cafe-cafe-cafecafecafe"), on: db).wait()
    print("t: \(String(describing:  t))")
}

run()
```

In the end, it took more time to set up a new test database for the issue. What’s more, it was trivial from that point on to iterate and try more things as instructed. Much more so than it would have been had it still been part of the [Swift Package Index server project](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server).

In some ways, creating this playground helped get this bug fixed. If we had not taken the time to reproduce the issue in a standalone way, it would have been difficult for the maintainers to be sure it was a problem they could fix.

Thanks again to [Fabian Fett](https://twitter.com/fabianfett), [Gwynne Raskind](https://twitter.com/_angeloidbeta) and [Johannes Weiss](https://twitter.com/johannesweiss) for their help and Fabian for the quick turnaround on the fix, and we hope this post also helps you file better bug reports!
