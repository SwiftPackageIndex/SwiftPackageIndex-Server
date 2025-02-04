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

import XCTVapor


class ProductTests: ParallelizedAppTestCase {

    func test_ProductType_Codable() throws {
        // Ensure ProductType is Codable in a way that's forward compatible with Swift 5.5's Codable synthesis for enums with associated types (SE-0295)
        let exe: ProductType = .executable
        let lib: ProductType = .library(.automatic)
        let test: ProductType = .test
        do {  // encoding
            XCTAssertEqual(
                String(decoding: try JSONEncoder().encode(exe), as: UTF8.self),
                #"{"executable":{}}"#
            )
            XCTAssertEqual(
                String(decoding: try JSONEncoder().encode(lib), as: UTF8.self),
                #"{"library":{"_0":"automatic"}}"#
            )
            XCTAssertEqual(
                String(decoding: try JSONEncoder().encode(test), as: UTF8.self),
                #"{"test":{}}"#
            )
        }
        do {  // decoding
            XCTAssertEqual(
                try JSONDecoder().decode(
                    ProductType.self,
                    from: Data(#"{"executable":{}}"#.utf8)),
                exe)
            XCTAssertEqual(
                try JSONDecoder().decode(
                    ProductType.self,
                    from: Data(#"{"library":{"_0":"automatic"}}"#.utf8)),
                lib
            )
            XCTAssertEqual(
                try JSONDecoder().decode(
                    ProductType.self,
                    from: Data(#"{"test":{}}"#.utf8)),
                test)
        }
    }

    func test_Product_save() async throws {
        let pkg = Package(id: UUID(), url: "1")
        let ver = try Version(id: UUID(), package: pkg)
        let prod = try Product(id: UUID(),
                               version: ver,
                               type: .library(.automatic),
                               name: "p1",
                               targets: ["t1", "t2"])
        try await pkg.save(on: app.db)
        try await ver.save(on: app.db)
        try await prod.save(on: app.db)
        do {
            let p = try await XCTUnwrapAsync(try await Product.find(prod.id, on: app.db))
            XCTAssertEqual(p.$version.id, ver.id)
            XCTAssertEqual(p.type, .library(.automatic))
            XCTAssertEqual(p.name, "p1")
            XCTAssertEqual(p.targets, ["t1", "t2"])
        }
    }

    func test_delete_cascade() async throws {
        // delete version must delete products
        let pkg = Package(id: UUID(), url: "1")
        let ver = try Version(id: UUID(), package: pkg)
        let prod = try Product(id: UUID(), version: ver, type: .library(.automatic), name: "p1")
        try await pkg.save(on: app.db)
        try await ver.save(on: app.db)
        try await prod.save(on: app.db)
        let db = app.db

        try await XCTAssertEqualAsync(try await Package.query(on: db).count(), 1)
        try await XCTAssertEqualAsync(try await Version.query(on: db).count(), 1)
        try await XCTAssertEqualAsync(try await Product.query(on: db).count(), 1)

        // MUT
        try await ver.delete(on: app.db)

        // version and product should be deleted
        try await XCTAssertEqualAsync(try await Package.query(on: db).count(), 1)
        try await XCTAssertEqualAsync(try await Version.query(on: db).count(), 0)
        try await XCTAssertEqualAsync(try await Product.query(on: db).count(), 0)
    }

}
