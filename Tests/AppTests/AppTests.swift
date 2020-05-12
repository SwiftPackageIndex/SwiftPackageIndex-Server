@testable import App

import Vapor
import XCTest


class AppTests: XCTestCase {

    func test_Filemanager_checkoutsDirectory() throws {
        Current.fileManager = .live
        XCTAssertEqual(Current.fileManager.checkoutsDirectory(),
                       DirectoryConfiguration.detect().workingDirectory + "SPI-checkouts")
        setenv("CHECKOUTS_DIR", "/tmp/foo", 1)
        XCTAssertEqual(Current.fileManager.checkoutsDirectory(), "/tmp/foo")
    }

}
