@testable import App

import SnapshotTesting
import Vapor
import XCTest
import Plot
import Ink


extension CGSize {
    static var desktop: Self { CGSize(width: 1200, height: 1500) }
    static var mobile: Self { CGSize(width: 375, height: 2000) }
}


let configs: [(name: String, size: CGSize)] = [
    ("desktop", .desktop),
    ("mobile", .mobile)
]


class WebpageSnapshotTests: WebpageSnapshotTestCase {

    func test_HomeIndexView() throws {
        let page = { HomeIndex.View(path: "/", model: .mock).document() }
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }
    
    func test_PackageShowView() throws {
        let page = { PackageShow.View(path: "", model: .mock, packageSchema: .mock).document() }
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }
    
    func test_PackageShowView_emoji_summary() throws {
        var model = PackageShow.Model.mock
        model.summary = ":package: Nothing but Cache. :octocat:"
        
        let page = { PackageShow.View(path: "", model: model, packageSchema: nil).document() }
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }

    func test_PackageShowView_open_source_license() throws {
        var model = PackageShow.Model.mock
        model.license = .mit
        model.licenseUrl = "https://example.com/license.html"

        let page = { PackageShow.View(path: "", model: model, packageSchema: nil).document() }
        assertSnapshot(matching: page, as: .html)

        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }

    func test_PackageShowView_app_store_incompatible_license() throws {
        var model = PackageShow.Model.mock
        model.license = .gpl_3_0
        model.licenseUrl = "https://example.com/license.html"

        let page = { PackageShow.View(path: "", model: model, packageSchema: nil).document() }
        assertSnapshot(matching: page, as: .html)

        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }

    func test_PackageShowView_other_license() throws {
        var model = PackageShow.Model.mock
        model.license = .other
        model.licenseUrl = "https://example.com/license.html"

        let page = { PackageShow.View(path: "", model: model, packageSchema: nil).document() }
        assertSnapshot(matching: page, as: .html)

        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }

    func test_PackageShowView_no_license() throws {
        var model = PackageShow.Model.mock
        model.license = .none
        model.licenseUrl = nil

        let page = { PackageShow.View(path: "", model: model, packageSchema: nil).document() }
        assertSnapshot(matching: page, as: .html)

        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
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
        let page = { PackageShow.View(path: "", model: model, packageSchema: nil).document() }
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
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
                status5_0: .compatible,
                status5_1: .compatible,
                status5_2: .compatible,
                status5_3: .compatible,
                status5_4: .compatible
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
        let page = { PackageShow.View(path: "", model: model, packageSchema: nil).document() }
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }

    func test_PackageReadmeView() throws {
        let model = PackageReadme.Model.mock
        let page = { PackageReadme.View(model: model).document() }

        assertSnapshot(matching: page, as: .html)

        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }


    func test_ErrorPageView() throws {
        let page = { ErrorPage.View(path: "", error: Abort(.notFound)).document() }
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }
    
    func test_MarkdownPage() throws {
        let page = { MarkdownPage(path: "", "privacy.md").document() }
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }
    
    func test_MarkdownPageStyling() throws {
        let data = try XCTUnwrap(try loadData(for: "markdown-test.md"))
        let markdown = try XCTUnwrap(String(data: data, encoding: .utf8))
        let html = MarkdownParser().parse(markdown).html
        let page = { MarkdownPage(path: "", html: html).document() }
        
        assertSnapshot(matching: page, as: .html)
        
        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                var mutableSize = $0.size
                mutableSize.height = 3000
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: mutableSize,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }

    func test_BuildIndex() throws {
        let page = { BuildIndex.View(path: "", model: .mock).document() }

        assertSnapshot(matching: page, as: .html)

        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }

    func test_BuildShow() throws {
        let page = { BuildShow.View(path: "", model: .mock).document() }

        assertSnapshot(matching: page, as: .html)

        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }

    func test_MaintainerInfoIndex() throws {
        let page = { MaintainerInfoIndex.View(path: "", model: .mock).document() }

        assertSnapshot(matching: page, as: .html)

        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: 0.999,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }
    
    func test_AuthorShow() throws {
        let page = { AuthorShow.View(path: "", model: .mock).document() }
        
        assertSnapshot(matching: page, as: .html)

        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: 0.999,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }

    func test_SearchShow() throws {
        let page = { SearchShow.View(path: "", model: .mock).document() }

        assertSnapshot(matching: page, as: .html)

        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }

    func test_KeywordShow() throws {
        let page = { KeywordShow.View(path: "", model: .mock).document() }

        assertSnapshot(matching: page, as: .html)

        #if os(macOS)
        if !isRunningInCI {
            configs.forEach {
                assertSnapshot(matching: page,
                               as: .image(precision: defaultPrecision,
                                          size: $0.size,
                                          baseURL: TempWebRoot.baseURL),
                               named: $0.name)
            }
        }
        #endif
    }

}
