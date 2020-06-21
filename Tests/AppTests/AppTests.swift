@testable import App

import Vapor
import XCTest


class AppTests: AppTestCase {

    func test_Filemanager_checkoutsDirectory() throws {
        Current.fileManager = .live
        unsetenv("CHECKOUTS_DIR")
        XCTAssertEqual(Current.fileManager.checkoutsDirectory(),
                       DirectoryConfiguration.detect().workingDirectory + "SPI-checkouts")
        setenv("CHECKOUTS_DIR", "/tmp/foo", 1)
        XCTAssertEqual(Current.fileManager.checkoutsDirectory(), "/tmp/foo")
    }

    func test_migrations() throws {
        XCTAssertNoThrow(try app.autoRevert().wait())
        XCTAssertNoThrow(try app.autoMigrate().wait())
    }
}
