// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import XCTest


class ManifestTests: XCTestCase {
    
    func test_decode_Product_Type() throws {
        // Test product type decoding.
        // JSON snippets via `swift package dump-package` from the following
        // Package.swift `products` definition:
        //        products: [
        //            .executable(name: "foo", targets: ["spm-test"]),
        //            .library(name: "spm-test-automatic",
        //                     targets: ["spm-test"]),
        //            .library(name: "spm-test-dynamic",
        //                     type: .dynamic, targets: ["spm-test"]),
        //            .library(name: "spm-test-static",
        //                     type: .static, targets: ["spm-test"])
        //        ],

        struct Test: Decodable, Equatable {
            var type: Manifest.ProductType
        }
        
        do { // exe
            let data = Data("""
            {
                "type": {
                    "executable": null
                }
            }
            """.utf8)
            XCTAssertEqual(try JSONDecoder().decode(Test.self, from: data),
                           .init(type: .executable))
        }
        do { // lib - automatic
            let data = Data("""
            {
                "type": {
                    "library": ["automatic"]
                }
            }
            """.utf8)
            XCTAssertEqual(try JSONDecoder().decode(Test.self, from: data),
                           .init(type: .library(.automatic)))
        }
        do { // lib - dynamic
            let data = Data("""
            {
                "type": {
                    "library": ["dynamic"]
                }
            }
            """.utf8)
            XCTAssertEqual(try JSONDecoder().decode(Test.self, from: data),
                           .init(type: .library(.dynamic)))
        }
        do { // lib - static
            let data = Data("""
            {
                "type": {
                    "library": ["static"]
                }
            }
            """.utf8)
            XCTAssertEqual(try JSONDecoder().decode(Test.self, from: data),
                           .init(type: .library(.static)))
        }
        do { // test
            let data = Data("""
            {
                "type": {
                    "test": null
                }
            }
            """.utf8)
            XCTAssertEqual(try JSONDecoder().decode(Test.self, from: data),
                           .init(type: .test))
        }
    }
    
    func test_decode_basic() throws {
        let data = try fixtureData(for: "manifest-1.json")
        let m = try JSONDecoder().decode(Manifest.self, from: data)
        XCTAssertEqual(m.name, "SPI-Server")
        XCTAssertEqual(m.platforms, [.init(platformName: .macos, version: "10.15")])
        XCTAssertEqual(m.products, [.init(name: "Some Product",
                                          targets: ["t1", "t2"],
                                          type: .library(.automatic))])
        XCTAssertEqual(m.swiftLanguageVersions, ["4", "4.2", "5"])
        XCTAssertEqual(m.targets, [.init(name: "App", type: .executableTarget),
                                   .init(name: "Run", type: .executableTarget),
                                   .init(name: "AppTests", type: .testTarget)])
        XCTAssertEqual(m.toolsVersion, .init(version: "5.2.0"))
    }

    func test_decode_products_complex() throws {
        let data = try fixtureData(for: "SwiftNIO.json")
        let m = try JSONDecoder().decode(Manifest.self, from: data)
        XCTAssertEqual(m.products, [
            .init(name: "NIOEchoServer",
                  targets: ["NIOEchoServer"],
                  type: .executable),
            .init(name: "NIOEchoClient",
                  targets: ["NIOEchoClient"],
                  type: .executable),
            .init(name: "NIOChatServer",
                  targets: ["NIOChatServer"],
                  type: .executable),
            .init(name: "NIOChatClient",
                  targets: ["NIOChatClient"],
                  type: .executable),
            .init(name: "NIOHTTP1Server",
                  targets: ["NIOHTTP1Server"],
                  type: .executable),
            .init(name: "NIOHTTP1Client",
                  targets: ["NIOHTTP1Client"],
                  type: .executable),
            .init(name: "NIOWebSocketServer",
                  targets: ["NIOWebSocketServer"],
                  type: .executable),
            .init(name: "NIOWebSocketClient",
                  targets: ["NIOWebSocketClient"],
                  type: .executable),
            .init(name: "NIOPerformanceTester",
                  targets: ["NIOPerformanceTester"],
                  type: .executable),
            .init(name: "NIOMulticastChat",
                  targets: ["NIOMulticastChat"],
                  type: .executable),
            .init(name: "NIOUDPEchoServer",
                  targets: ["NIOUDPEchoServer"],
                  type: .executable),
            .init(name: "NIOUDPEchoClient",
                  targets: ["NIOUDPEchoClient"],
                  type: .executable),
            .init(name: "NIO",
                  targets: ["NIO"],
                  type: .library(.automatic)),
            .init(name: "_NIO1APIShims",
                  targets: ["_NIO1APIShims"],
                  type: .library(.automatic)),
            .init(name: "NIOTLS",
                  targets: ["NIOTLS"],
                  type: .library(.automatic)),
            .init(name: "NIOHTTP1",
                  targets: ["NIOHTTP1"],
                  type: .library(.automatic)),
            .init(name: "NIOConcurrencyHelpers",
                  targets: ["NIOConcurrencyHelpers"],
                  type: .library(.automatic)),
            .init(name: "NIOFoundationCompat",
                  targets: ["NIOFoundationCompat"],
                  type: .library(.automatic)),
            .init(name: "NIOWebSocket",
                  targets: ["NIOWebSocket"],
                  type: .library(.automatic)),
            .init(name: "NIOTestUtils",
                  targets: ["NIOTestUtils"],
                  type: .library(.automatic)),
        ])
    }
    
    func test_platform_list() throws {
        // Test to ensure the platforms listed in the DTO struct Manifest.Platform.Name
        // do not accidentally diverge from those in the db entity's Platform.Name
        XCTAssertEqual(Set(Manifest.Platform.Name.allCases.map(\.rawValue)),
                       Set(Platform.Name.allCases.map(\.rawValue)))
    }

    func test_decode_plugin_products() throws {
        let data = try fixtureData(for: "manifest-plugin.json")
        let m = try JSONDecoder().decode(Manifest.self, from: data)
        XCTAssertEqual(m.products, [
            .init(name: "Swift-DocC", targets: ["Swift-DocC"], type: .plugin),
            .init(name: "Swift-DocC Preview", targets: ["Swift-DocC Preview"], type: .plugin),
        ])
    }

}

