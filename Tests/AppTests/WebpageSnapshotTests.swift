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
        Current.date = { Date(timeIntervalSince1970: 0) }
        TempWebRoot.cleanup()
    }
    
    override class func setUp() {
        TempWebRoot.setup()
    }
    
    func test_admin() throws {
        try XCTSkipIf(true, "currently not deploying admin page")
        let page: () -> HTML = { PublicPage.admin() }
        
        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests
        
        assertSnapshot(matching: page, as: .html)
        
        // Snapshot renders slightly differently on macOS 11 (swift 5.3) - exclude it for now
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
    
    func test_HomeIndexView() throws {
        let page = { HomeIndex.View(path: "/", model: .mock).document() }
        
        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests
        
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
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests
        
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
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests
        
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
        model.license = License.none
        let page = { PackageShow.View(path: "", model: model).document() }
        
        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests
        
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
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests
        
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
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests
        
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
    
    func test_PackageShowView_no_lpInfo() throws {
        // Test display when there is no L&P info at all
        // no author or activity info
        var model = PackageShow.Model.mock
        model.languagePlatforms = .init(stable: nil, beta: nil, latest: nil)
        let page = { PackageShow.View(path: "", model: model).document() }
        
        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests
        
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
    
    func test_PackageShowView_no_platforms() throws {
        // Test display when there is no platform info
        // see: https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/pull/195#issue-424606548
        var model = PackageShow.Model.mock
        model.languagePlatforms.stable?.platforms = []
        model.languagePlatforms.beta?.platforms = []
        model.languagePlatforms.latest?.platforms = []
        let page = { PackageShow.View(path: "", model: model).document() }
        
        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests
        
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
    
    func test_PackageShowView_no_versions() throws {
        // Test display when there is no version info
        // see: https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/pull/195#issue-424606548
        var model = PackageShow.Model.mock
        model.languagePlatforms.stable?.swiftVersions = []
        model.languagePlatforms.beta?.swiftVersions = []
        model.languagePlatforms.latest?.swiftVersions = []
        let page = { PackageShow.View(path: "", model: model).document() }
        
        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests
        
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
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests
        
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
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests
        
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
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests

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
