@testable import App

import SnapshotTesting
import Vapor
import XCTest


let defaultSize = CGSize(width: 800, height: 600)
let recordSnapshotForAllTests = false

class WebpageSnapshotTests: XCTestCase {

    override func setUpWithError() throws {
        Current.date = { Date(timeIntervalSince1970: 0) }
    }

    func test_home() throws {
        let page = PublicPage.admin()

        let recordSnapshotForThisTest = false
        record = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page.render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            assertSnapshot(matching: page, as: .image(size: defaultSize, baseURL: baseURL()))
        }
        #endif
    }

    func test_HomeIndexView() throws {
        let page = HomeIndex.View(path: "/", model: .mock).document()

        let recordSnapshotForThisTest = false
        record = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page.render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            // FIXME: css and image loading broken, despite setting correct base url
            // permission issue? In a macOS app project this required setting
            // com.apple.security.network.client permissions but I don't see how to do
            // that with SPM - nor would I expect to need that for tests?
            assertSnapshot(matching: page, as: .image(size: .init(width: 800, height: 800),
                                                      baseURL: baseURL()))
        }
        #endif
    }

    func test_PackageShowView() throws {
        let page = PackageShow.View(path: "", model: .mock).document()

        let recordSnapshotForThisTest = false
        record = recordSnapshotForThisTest || recordSnapshotForAllTests

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
        let page = PackageShow.View(path: "", model: model).document()

        let recordSnapshotForThisTest = false
        record = recordSnapshotForThisTest || recordSnapshotForAllTests

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

    func test_PackageShowView_incompatible_license() throws {
        var model = PackageShow.Model.mock
        model.license = License.gpl_3_0
        let page = PackageShow.View(path: "", model: model).document()

        let recordSnapshotForThisTest = false
        record = recordSnapshotForThisTest || recordSnapshotForAllTests

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

    func test_PackageShowView_no_authors_activity() throws {
        // Test to ensure we don't display empty bullet points when there is
        // no author or activity info
        var model = PackageShow.Model.mock
        model.authors = nil
        model.activity = nil
        let page = PackageShow.View(path: "", model: model).document()

        let recordSnapshotForThisTest = false
        record = recordSnapshotForThisTest || recordSnapshotForAllTests

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

    func test_PackageShowView_no_lpInfo() throws {
        // Test display when there is no L&P info at all
        // no author or activity info
        var model = PackageShow.Model.mock
        model.languagePlatforms = .init(stable: nil, beta: nil, latest: nil)
        let page = PackageShow.View(path: "", model: model).document()

        let recordSnapshotForThisTest = false
        record = recordSnapshotForThisTest || recordSnapshotForAllTests

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

    func test_PackageShowView_no_platforms() throws {
        // Test display when there is no platform info
        // see: https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/pull/195#issue-424606548
        var model = PackageShow.Model.mock
        model.languagePlatforms.stable?.platforms = []
        model.languagePlatforms.beta?.platforms = []
        model.languagePlatforms.latest?.platforms = []
        let page = PackageShow.View(path: "", model: model).document()

        let recordSnapshotForThisTest = false
        record = recordSnapshotForThisTest || recordSnapshotForAllTests

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

    func test_PackageShowView_no_versions() throws {
        // Test display when there is no version info
        // see: https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/pull/195#issue-424606548
        var model = PackageShow.Model.mock
        model.languagePlatforms.stable?.swiftVersions = []
        model.languagePlatforms.beta?.swiftVersions = []
        model.languagePlatforms.latest?.swiftVersions = []
        let page = PackageShow.View(path: "", model: model).document()

        let recordSnapshotForThisTest = false
        record = recordSnapshotForThisTest || recordSnapshotForAllTests

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

    func test_ErrorPageView() throws {
        let model = ErrorPage.Model(Abort(.notFound))
        let page = ErrorPage.View(path: "", model: model).document()

        let recordSnapshotForThisTest = false
        record = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page.render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            // FIXME: css and image loading broken, despite setting correct base url
            // permission issue? In a macOS app project this required setting
            // com.apple.security.network.client permissions but I don't see how to do
            // that with SPM - nor would I expect to need that for tests?
            assertSnapshot(matching: page, as: .image(size: .init(width: 800, height: 800),
                                                      baseURL: baseURL()))
        }
        #endif
    }

    func test_MarkdownPage() throws {
        let page = MarkdownPage(path: "", "privacy.md").document()

        let recordSnapshotForThisTest = false
        record = recordSnapshotForThisTest || recordSnapshotForAllTests

        assertSnapshot(matching: page.render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            // FIXME: css and image loading broken, despite setting correct base url
            // permission issue? In a macOS app project this required setting
            // com.apple.security.network.client permissions but I don't see how to do
            // that with SPM - nor would I expect to need that for tests?
            assertSnapshot(matching: page, as: .image(size: .init(width: 800, height: 800),
                                                      baseURL: baseURL()))
        }
        #endif
    }

}


func baseURL(_ path: String = #file) -> URL {
    URL(fileURLWithPath: DirectoryConfiguration.detect().workingDirectory + "Public/")
}
