@testable import App

import SnapshotTesting
import Vapor
import XCTest
import Plot


extension CGSize {
    static var desktop: Self { CGSize(width: 1200, height: 1500) }
    static var mobile: Self { CGSize(width: 375, height: 2000) }
}


let configs: [(name: String, size: CGSize)] = [
    ("desktop", .desktop),
    ("mobile", .mobile)
]


let recordSnapshotForAllTests = false


class WebpageSnapshotTests: XCTestCase {
    
    override func setUpWithError() throws {
        try XCTSkipIf((Environment.get("SKIP_SNAPSHOTS") ?? "false") == "true")
        Current.date = { Date(timeIntervalSince1970: 0) }
        TempWebRoot.cleanup()
    }
    
    override class func setUp() {
        TempWebRoot.setup()
    }
    
    func test_HomeIndexView() throws {
        let page = { HomeIndex.View(path: "/", model: .mock).document() }
        
        let recordSnapshotForThisTest = false
        SnapshotTesting.isRecording = recordSnapshotForThisTest || recordSnapshotForAllTests
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(size: $0.size, baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }
    
    func test_PackageShowView() throws {
        let page = { PackageShow.View(path: "", model: .mock).document() }
        
        let recordSnapshotForThisTest = false
        SnapshotTesting.isRecording = recordSnapshotForThisTest || recordSnapshotForAllTests
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(size: $0.size, baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }
    
    func test_PackageShowView_emoji_summary() throws {
        var model = PackageShow.Model.mock
        model.summary = ":package: Nothing but Cache. :octocat:"
        
        let page = { PackageShow.View(path: "", model: model).document() }
        
        let recordSnapshotForThisTest = false
        SnapshotTesting.isRecording = recordSnapshotForThisTest || recordSnapshotForAllTests
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(size: $0.size, baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }
    
    func test_PackageShowView_unknown_license() throws {
        var model = PackageShow.Model.mock
        model.license = License.other
        let page = { PackageShow.View(path: "", model: model).document() }
        
        let recordSnapshotForThisTest = false
        SnapshotTesting.isRecording = recordSnapshotForThisTest || recordSnapshotForAllTests
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(size: $0.size, baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }
    
    func test_PackageShowView_incompatible_license() throws {
        var model = PackageShow.Model.mock
        model.license = License.gpl_3_0
        let page = { PackageShow.View(path: "", model: model).document() }
        
        let recordSnapshotForThisTest = false
        SnapshotTesting.isRecording = recordSnapshotForThisTest || recordSnapshotForAllTests
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(size: $0.size, baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }
    
    func test_PackageShowView_no_authors_activity() throws {
        // Test to ensure we don't display empty bullet points when there is
        // no author or activity info
        var model = PackageShow.Model.mock
        model.authors = nil
        model.activity = nil
        let page = { PackageShow.View(path: "", model: model).document() }
        
        let recordSnapshotForThisTest = false
        SnapshotTesting.isRecording = recordSnapshotForThisTest || recordSnapshotForAllTests
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(size: $0.size, baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }
    
    func test_PackageShowView_single_row_tables() throws {
        // Test display when all three significant version collapse to a single row
        var model = PackageShow.Model.mock
        do {
            let compatible = PackageShow.Model.SwiftVersionResults(
                status4_2: .compatible,
                status5_0: .compatible,
                status5_1: .compatible,
                status5_2: .compatible,
                status5_3: .compatible
            )
            model.swiftVersionBuildInfo = .init(
                stable: .init(referenceName: "5.2.5", results: compatible),
                beta: .init(referenceName: "6.0.0-b1", results: compatible),
                latest: .init(referenceName: "main", results: compatible)
            )
        }
        do {
            let compatible = PackageShow.Model.PlatformResults(
                iosStatus: .compatible,
                linuxStatus: .compatible,
                macosStatus: .compatible,
                macosArmStatus: .compatible,
                tvosStatus: .compatible,
                watchosStatus: .compatible
            )
            model.platformBuildInfo = .init(
                stable: .init(referenceName: "5.2.5", results: compatible),
                beta: .init(referenceName: "6.0.0-b1", results: compatible),
                latest: .init(referenceName: "main", results: compatible)
            )
        }
        let page = { PackageShow.View(path: "", model: model).document() }
        
        let recordSnapshotForThisTest = false
        SnapshotTesting.isRecording = recordSnapshotForThisTest || recordSnapshotForAllTests
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(size: $0.size, baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }
    
    func test_ErrorPageView() throws {
        let model = ErrorPage.Model(Abort(.notFound))
        let page = { ErrorPage.View(path: "", model: model).document() }
        
        let recordSnapshotForThisTest = false
        SnapshotTesting.isRecording = recordSnapshotForThisTest || recordSnapshotForAllTests
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(size: $0.size, baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }
    
    func test_MarkdownPage() throws {
        let page = { MarkdownPage(path: "", "privacy.md").document() }
        
        let recordSnapshotForThisTest = false
        SnapshotTesting.isRecording = recordSnapshotForThisTest || recordSnapshotForAllTests
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(size: $0.size, baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }

    func test_BuildIndex() throws {
        let page = { BuildIndex.View(path: "", model: .mock).document() }

        let recordSnapshotForThisTest = false
        SnapshotTesting.isRecording = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page, as: .html)

        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(size: $0.size, baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }

    func test_BuildShow() throws {
        let page = { BuildShow.View(path: "", model: .mock).document() }

        let recordSnapshotForThisTest = false
        SnapshotTesting.isRecording = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page, as: .html)

        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(size: $0.size, baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }

}
