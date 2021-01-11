//
@testable import App

import XCTest


class ManifestTests: XCTestCase {
    
    func test_decode_Product_Type() throws {
        do { // exe
            let json = """
            {
                "type": {
                    "executable": null
                }
            }
            """
            let data = Data(json.utf8)
            struct Test: Decodable, Equatable {
                var type: Manifest.Product.`Type`
            }
            XCTAssertEqual(try JSONDecoder().decode(Test.self, from: data), .init(type: .executable))
        }
        do { // lib
            let json = """
            {
                "type": {
                    "library": ["automatic"]
                }
            }
            """
            let data = Data(json.utf8)
            struct Test: Decodable, Equatable {
                var type: Manifest.Product.`Type`
            }
            XCTAssertEqual(try JSONDecoder().decode(Test.self, from: data), .init(type: .library))
        }
    }
    
    func test_decode_basic() throws {
        let data = try loadData(for: "manifest-1.json")
        let m = try JSONDecoder().decode(Manifest.self, from: data)
        XCTAssertEqual(m.name, "SPI-Server")
        XCTAssertEqual(m.platforms, [.init(platformName: .macos, version: "10.15")])
        XCTAssertEqual(m.products, [.init(name: "Some Product",
                                          targets: ["t1", "t2"],
                                          type: .library)])
        XCTAssertEqual(m.swiftLanguageVersions, ["4", "4.2", "5"])
        XCTAssertEqual(m.targets, [.init(name: "App"),
                                   .init(name: "Run"),
                                   .init(name: "AppTests")])
        XCTAssertEqual(m.toolsVersion, .init(version: "5.2.0"))
    }

    func test_decode_products_complex() throws {
        let data = try loadData(for: "SwiftNIO.json")
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
                  type: .library),
            .init(name: "_NIO1APIShims",
                  targets: ["_NIO1APIShims"],
                  type: .library),
            .init(name: "NIOTLS",
                  targets: ["NIOTLS"],
                  type: .library),
            .init(name: "NIOHTTP1",
                  targets: ["NIOHTTP1"],
                  type: .library),
            .init(name: "NIOConcurrencyHelpers",
                  targets: ["NIOConcurrencyHelpers"],
                  type: .library),
            .init(name: "NIOFoundationCompat",
                  targets: ["NIOFoundationCompat"],
                  type: .library),
            .init(name: "NIOWebSocket",
                  targets: ["NIOWebSocket"],
                  type: .library),
            .init(name: "NIOTestUtils",
                  targets: ["NIOTestUtils"],
                  type: .library),
        ])
    }
    
    func test_platform_list() throws {
        // Test to ensure the platforms listed in the DTO struct Manifest.Platform.Name
        // do not accidentally diverge from those in the db entity's Platform.Name
        XCTAssertEqual(Set(Manifest.Platform.Name.allCases.map(\.rawValue)),
                       Set(Platform.Name.allCases.map(\.rawValue)))
    }

}

