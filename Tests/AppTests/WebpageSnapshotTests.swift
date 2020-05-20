@testable import App

import SnapshotTesting
import Vapor
import XCTest


let defaultSize = CGSize(width: 800, height: 600)

class WebpageSnapshotTests: XCTestCase {

    override func setUpWithError() throws {
        Current.date = { Date(timeIntervalSince1970: 0) }
    }

    func test_home() throws {
        let page = PublicPage.admin()

        assertSnapshot(matching: page.render(indentedBy: .spaces(2)), as: .lines)

        #if os(macOS)
        if !isRunningInCI {
            assertSnapshot(matching: page, as: .image(size: defaultSize, baseURL: baseURL()))
        }
        #endif
    }

    func test_HomeIndexView() throws {
        let page = HomeIndexView().document()

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
        let page = PackageShowView(.mock).document()

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
