@testable import App

import SnapshotTesting
import Vapor
import XCTest
import Plot

let recordSnapshotForAllTests = true

class WebpageSnapshotTests: XCTestCase {

    static var testCoordinator = SnapshotTestCoordinator()
    
    override func setUpWithError() throws {
        Current.date = { Date(timeIntervalSince1970: 0) }
        WebpageSnapshotTests.testCoordinator.cleanup()
        setSiteURL(forImageSnapshot: false)
    }
    
    override class func setUp() {
        testCoordinator.setup()
    }

    func test_home() throws {
        let page: () -> HTML = { PublicPage.admin() }

        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page().render(indentedBy: .spaces(2)), as: .lines)

        // Snapshot renders slightly differently on macOS 11 (swift 5.3) - exclude it for now
        #if os(macOS) && swift(<5.3)
        if !isRunningInCI {
            assertHTMLSnapshot(forPage: page)
        }
        #endif
    }

    func test_HomeIndexView() throws {
        let page: () -> HTML = { HomeIndex.View(path: "/", model: .mock).document() }

        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page().render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            assertHTMLSnapshot(forPage: page)
        }
        #endif
    }

    func test_PackageShowView() throws {
        let page: () -> HTML = { PackageShow.View(path: "", model: .mock).document() }

        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page().render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            assertHTMLSnapshot(forPage: page)
        }
        #endif
    }
    
    func test_PackageShowView_emoji_summary() throws {
        var model = PackageShow.Model.mock
        model.summary = ":package: Nothing but Cache. :octocat:"
        
        let page = PackageShow.View(path: "", model: model).document()

        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page.render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            // FIXME: css and image loading broken, despite setting correct base url
            // permission issue? In a macOS app project this required setting
            // com.apple.security.network.client permissions but I don't see how to do
            // that with SPM - nor would I expect to need that for tests?
            assertSnapshot(matching: page, as: .image(size: .init(width: 800, height: 1000),
                                                      baseURL: baseURL()))
        }
        #endif
    }

    func test_PackageShowView_unknown_license() throws {
        var model = PackageShow.Model.mock
        model.license = License.none
        let page: () -> HTML = { PackageShow.View(path: "", model: model).document() }

        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page().render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            assertHTMLSnapshot(forPage: page)
        }
        #endif
    }

    func test_PackageShowView_incompatible_license() throws {
        var model = PackageShow.Model.mock
        model.license = License.gpl_3_0
        let page: () -> HTML = { PackageShow.View(path: "", model: model).document() }

        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page().render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            assertHTMLSnapshot(forPage: page)
        }
        #endif
    }

    func test_PackageShowView_no_authors_activity() throws {
        // Test to ensure we don't display empty bullet points when there is
        // no author or activity info
        var model = PackageShow.Model.mock
        model.authors = nil
        model.activity = nil
        let page: () -> HTML = { PackageShow.View(path: "", model: model).document() }

        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page().render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            assertHTMLSnapshot(forPage: page)
        }
        #endif
    }

    func test_PackageShowView_no_lpInfo() throws {
        // Test display when there is no L&P info at all
        // no author or activity info
        var model = PackageShow.Model.mock
        model.languagePlatforms = .init(stable: nil, beta: nil, latest: nil)
        let page: () -> HTML = { PackageShow.View(path: "", model: model).document() }

        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page().render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            assertHTMLSnapshot(forPage: page)
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
        let page: () -> HTML = { PackageShow.View(path: "", model: model).document() }

        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page().render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            assertHTMLSnapshot(forPage: page)
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
        let page: () -> HTML = { PackageShow.View(path: "", model: model).document() }

        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page().render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            assertHTMLSnapshot(forPage: page)
        }
        #endif
    }

    func test_ErrorPageView() throws {
        let model = ErrorPage.Model(Abort(.notFound))
        let page: () -> HTML = { ErrorPage.View(path: "", model: model).document() }

        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page().render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            assertHTMLSnapshot(forPage: page)
        }
        #endif
    }

    func test_MarkdownPage() throws {
        let page: () -> HTML = { MarkdownPage(path: "", "privacy.md").document() }

        let recordSnapshotForThisTest = false
        SnapshotTesting.record = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page().render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            assertHTMLSnapshot(forPage: page)
        }
        #endif
    }
    
    func setSiteURL(forImageSnapshot: Bool) {
        Current.siteURL = { forImageSnapshot ? WebpageSnapshotTests.testCoordinator.siteURL : "http://localhost:8080" }
    }
    
    func assertHTMLSnapshot(
        forPage page: () -> HTML,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        setSiteURL(forImageSnapshot: true)
        
        let mobile: Snapshotting<HTML, NSImage> = .image(
            size: .init(width: 375, height: 1600),
            baseURL: WebpageSnapshotTests.testCoordinator.baseURL
        )
        
        let desktop: Snapshotting<HTML, NSImage> = .image(
            size: .init(width: 1200, height: 1200),
            baseURL: WebpageSnapshotTests.testCoordinator.baseURL
        )
        
        assertSnapshot(matching: page(), as: mobile, named: "mobile", file: file, testName: testName, line: line)
        assertSnapshot(matching: page(), as: desktop, named: "desktop", file: file, testName: testName, line: line)
    }

}
