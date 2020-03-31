// swiftlint:disable force_try
// swiftlint:disable force_unwrapping

import FluentPostgreSQL
import Vapor
import XCTest

@testable import App

final class PackageTests: XCTestCase {
  var app: Application!
  var database: PostgreSQLConnection!

  override func setUp() {
    super.setUp()

    try! Application.reset()
    app = try! Application.testable()
    database = try! app.newConnection(to: .psql).wait()
  }

  override func tearDown() {
    super.tearDown()

    database.close()
    try? app.syncShutdownGracefully()
  }

  func testPackageCreationWithUrl() throws {
    let url = URL(string: "https://example.com/")!
    let package = Package(url: url)
    XCTAssertEqual(package.url, url)
  }

  func testFindPackageByURL() throws {
    let alamofireUrlString = "https://github.com/Alamofire/Alamofire.git"
    TestData.createPackage(on: database, urlString: alamofireUrlString)

    let existingUrl = URL(string: alamofireUrlString)!
    let existingPackage = try Package.findByUrl(on: database, url: existingUrl).wait()
    XCTAssertEqual(existingPackage.url, existingUrl)

    let nonExistentUrl = URL(string: "https://github.com/apple/shiny.git")!
    XCTAssertThrowsError(try Package.findByUrl(on: database, url: nonExistentUrl).wait()) { error in
      XCTAssertEqual(error as? PackageError, PackageError.recordNotFound)
    }
  }
}
