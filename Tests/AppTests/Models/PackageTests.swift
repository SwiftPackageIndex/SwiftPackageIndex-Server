import Vapor
import FluentPostgreSQL
import XCTest

@testable import App

final class PackageTests: XCTestCase
{
  var app: Application!
  var conn: PostgreSQLConnection!

  func testPackageCreationWithUrl() throws
  {
    let url = URL(string: "https://example.com/")!
    let package = Package(url: url)
    XCTAssertEqual(package.url, url)
  }

  static let allTests = [
    ("testPackageCreationWithUrl", testPackageCreationWithUrl)
  ]
}
