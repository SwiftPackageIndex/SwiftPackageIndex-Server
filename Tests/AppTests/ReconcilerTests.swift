// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import App

import Dependencies
import Testing
import Vapor


extension AllTests.ReconcilerTests {

    @Test func fetchCurrentPackageList() async throws {
        try await withApp { app in
            // setup
            for url in ["1", "2", "3"].asURLs {
                try await Package(url: url).save(on: app.db)
            }

            // MUT
            let urls = try await App.fetchCurrentPackageList(app.db)

            // validate
            #expect(urls.map(\.absoluteString).sorted() == ["1", "2", "3"])
        }
    }

    @Test func reconcileMainPackageList() async throws {
        try await withApp { app in
            let urls = ["1", "2", "3"]
            try await withDependencies {
                $0.packageListRepository.fetchPackageList = { @Sendable _ in urls.asURLs }
                $0.packageListRepository.fetchPackageDenyList = { @Sendable _ in [] }
            } operation: {
                // MUT
                _ = try await App.reconcileMainPackageList(client: app.client, database: app.db)
            }

            // validate
            let packages = try await Package.query(on: app.db).all()
            #expect(packages.map(\.url).sorted() == urls.sorted())
            packages.forEach {
                #expect($0.id != nil)
                #expect($0.createdAt != nil)
                #expect($0.updatedAt != nil)
                #expect($0.status == .new)
                #expect($0.processingStage == .reconciliation)
            }
        }
    }

    @Test func reconcileMainPackageList_adds_and_deletes() async throws {
        try await withApp { app in
            // save intial set of packages 1, 2, 3
            for url in ["1", "2", "3"].asURLs {
                try await Package(url: url).save(on: app.db)
            }

            // new package list drops 2, 3, adds 4, 5
            let urls = ["1", "4", "5"]

            try await withDependencies {
                $0.packageListRepository.fetchPackageList = { @Sendable _ in urls.asURLs }
                $0.packageListRepository.fetchPackageDenyList = { @Sendable _ in [] }
            } operation: {
                // MUT
                _ = try await App.reconcileMainPackageList(client: app.client, database: app.db)
            }

            // validate
            let packages = try await Package.query(on: app.db).all()
            #expect(packages.map(\.url).sorted() == urls.sorted())
        }
    }

    @Test func reconcileMainPackageList_packageDenyList() async throws {
        try await withApp { app in
            // Save the intial set of packages
            for url in ["1", "2", "3"].asURLs {
                try await Package(url: url).save(on: app.db)
            }

            // New list adds two new packages 4, 5
            let packageList = ["1", "2", "3", "4", "5"]

            // Deny list denies 2 and 4 (one existing and one new)
            let packageDenyList = ["2", "4"]

            try await withDependencies {
                $0.packageListRepository.fetchPackageList = { @Sendable _ in packageList.asURLs }
                $0.packageListRepository.fetchPackageDenyList = { @Sendable _ in packageDenyList.asURLs }
            } operation: {
                // MUT
                _ = try await App.reconcileMainPackageList(client: app.client, database: app.db)
            }

            // validate
            let packages = try await Package.query(on: app.db).all()
            #expect(packages.map(\.url).sorted() == ["1", "3", "5"])
        }
    }

    @Test func reconcileMainPackageList_packageDenyList_caseSensitivity() async throws {
        try await withApp { app in
            // Save the intial set of packages
            for url in ["https://example.com/one/one", "https://example.com/two/two"].asURLs {
                try await Package(url: url).save(on: app.db)
            }

            // New list adds no new packages
            let packageList = ["https://example.com/one/one", "https://example.com/two/two"]

            // Deny list denies one/one, but with incorrect casing.
            let packageDenyList = ["https://example.com/OnE/oNe"]

            try await withDependencies {
                $0.packageListRepository.fetchPackageList = { @Sendable _ in packageList.asURLs }
                $0.packageListRepository.fetchPackageDenyList = { @Sendable _ in packageDenyList.asURLs }
            } operation: {
                // MUT
                _ = try await App.reconcileMainPackageList(client: app.client, database: app.db)
            }

            // validate
            let packages = try await Package.query(on: app.db).all()
            #expect(packages.map(\.url).sorted() == ["https://example.com/two/two"])
        }
    }

    @Test func reconcileCustomCollections() async throws {
        // Test single custom collection reconciliation
        try await withApp { app in
            // setup
            var fullPackageList = [URL("https://github.com/a.git"), URL("https://github.com/b.git"), URL("https://github.com/c.git")]
            for url in fullPackageList { try await Package(url: url).save(on: app.db) }

            // Initial run
            try await withDependencies {
                $0.packageListRepository.fetchCustomCollection = { @Sendable _, _ in [URL("https://github.com/b.git")] }
            } operation: {
                // MUT
                try await reconcileCustomCollection(client: app.client,
                                                    database: app.db,
                                                    fullPackageList: fullPackageList,
                                                    .init(key: "list", name: "List", url: "url"))

                // validate
                let count = try await CustomCollection.query(on: app.db).count()
                #expect(count == 1)
                let collection = try await CustomCollection.query(on: app.db).first().unwrap()
                try await collection.$packages.load(on: app.db)
                #expect(collection.packages.map(\.url) == ["https://github.com/b.git"])
            }

            // Reconcile again with an updated list of packages in the collection
            try await withDependencies {
                $0.packageListRepository.fetchCustomCollection = { @Sendable _, _ in [URL("https://github.com/c.git")] }
            } operation: {
                // MUT
                try await reconcileCustomCollection(client: app.client,
                                                    database: app.db,
                                                    fullPackageList: fullPackageList,
                                                    .init(key: "list", name: "List", url: "url"))

                // validate
                let count = try await CustomCollection.query(on: app.db).count()
                #expect(count == 1)
                let collection = try await CustomCollection.query(on: app.db).first().unwrap()
                try await collection.$packages.load(on: app.db)
                #expect(collection.packages.map(\.url) == ["https://github.com/c.git"])
            }

            // Re-run after the single package in the list has been deleted in the full package list
            fullPackageList = [URL("https://github.com/a.git"), URL("https://github.com/b.git")]
            try await Package.query(on: app.db).filter(by: URL("https://github.com/c.git")).first()?.delete(on: app.db)
            try await withDependencies {
                $0.packageListRepository.fetchCustomCollection = { @Sendable _, _ in [URL("https://github.com/c.git")] }
            } operation: {
                // MUT
                try await reconcileCustomCollection(client: app.client,
                                                    database: app.db,
                                                    fullPackageList: fullPackageList,
                                                    .init(key: "list", name: "List", url: "url"))

                // validate
                let count = try await CustomCollection.query(on: app.db).count()
                #expect(count == 1)
                let collection = try await CustomCollection.query(on: app.db).first().unwrap()
                try await collection.$packages.load(on: app.db)
                #expect(collection.packages.map(\.url) == [])
            }
        }
    }

    @Test func reconcileCustomCollections_limit() async throws {
        // Test custom collection reconciliation size limit
        try await withApp { app in
            // setup
            let fullPackageList = (1...60).map { URL(string: "https://github.com/\($0).git")! }
            for url in fullPackageList { try await Package(url: url).save(on: app.db) }

            try await withDependencies {
                $0.packageListRepository.fetchCustomCollection = { @Sendable _, _ in
                    fullPackageList
                }
            } operation: {
                // MUT
                try await reconcileCustomCollection(client: app.client,
                                                    database: app.db,
                                                    fullPackageList: fullPackageList,
                                                    .init(key: "list", name: "List", url: "url"))

                // validate
                let collection = try await CustomCollection.query(on: app.db).first().unwrap()
                try await collection.$packages.load(on: app.db)
                #expect(collection.packages.count == 50)
                #expect(collection.packages.first?.url == "https://github.com/1.git")
                #expect(collection.packages.last?.url == "https://github.com/50.git")
            }
        }
    }

    @Test func reconcile() async throws {
        let fullPackageList = (1...3).map { URL(string: "https://github.com/\($0).git")! }
        struct TestError: Error { var message: String }

        try await withDependencies {
            $0.packageListRepository.fetchPackageList = { @Sendable _ in fullPackageList }
            $0.packageListRepository.fetchPackageDenyList = { @Sendable _ in [] }
            $0.packageListRepository.fetchCustomCollection = { @Sendable _, url in
                if url == "collectionURL" {
                    return [URL("https://github.com/2.git")]
                } else {
                    throw TestError(message: "collection not found: \(url)")
                }
            }
            $0.packageListRepository.fetchCustomCollections = { @Sendable _ in
                [.init(key: "list", name: "List", url: "collectionURL")]
            }
        } operation: {
            try await withApp { app in
                // MUT
                _ = try await App.reconcile(client: app.client, database: app.db)

                // validate
                let packages = try await Package.query(on: app.db).all()
                #expect(packages.map(\.url).sorted() == fullPackageList.map(\.absoluteString).sorted())
                let count = try await CustomCollection.query(on: app.db).count()
                #expect(count == 1)
                let collection = try await CustomCollection.query(on: app.db).first().unwrap()
                #expect(collection.name == "List")
                #expect(collection.url == "collectionURL")
                try await collection.$packages.load(on: app.db)
                #expect(collection.packages.map(\.url) == ["https://github.com/2.git"])
            }
        }
    }

}
