import Vapor
import FluentPostgreSQL
import XCTest

@testable import App

final class PackageTests: XCTestCase
{
  var app: Application!
  var database: PostgreSQLConnection!

  override func setUp()
  {
    try! Application.reset()
    app = try! Application.testable()
    database = try! app.newConnection(to: .psql).wait()

    // Create a couple of test packages that can be relied on during a test
    createTestPackage(from: "https://github.com/vapor/vapor.git")
    createTestPackage(from: "https://github.com/Alamofire/Alamofire.git")
  }

  override func tearDown()
  {
    database.close()
    try? app.syncShutdownGracefully()
  }

  func testPackageCreationWithUrl() throws
  {
    let url = URL(string: "https://example.com/")!
    let package = Package(url: url)
    XCTAssertEqual(package.url, url)
  }

  func testFindPackageByURL() throws
  {
    let existingUrl = URL(string: "https://github.com/Alamofire/Alamofire.git")!
    let existingPackage = try Package.findByUrl(on: database, url: existingUrl).wait()
    XCTAssertEqual(existingPackage.url, existingUrl)

    let nonExistentUrl = URL(string: "https://github.com/apple/shiny.git")!
    let nonExistentPackage = try Package.findByUrl(on: database, url: nonExistentUrl).wait()
    XCTAssertNil(nonExistentPackage)
  }

  /// Helper method to create test Package data.
  /// - Parameter urlString: A string containing a valid URL.
  func createTestPackage(from urlString: String)
  {
    guard let url = URL(string: urlString)
      else { preconditionFailure("Expected a valid URL") }
    let package = Package(url: url)
    let _ = try! package.create(on: database).wait()
  }

  static let allTests = [
    ("testPackageCreationWithUrl", testPackageCreationWithUrl),
    ("testFindPackageByURL", testFindPackageByURL)
  ]
}
