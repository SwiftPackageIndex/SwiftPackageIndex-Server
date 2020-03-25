import Vapor
import FluentPostgreSQL
import XCTest

@testable import App

final class PackageTests: DatabaseTestCase
{
  override func setUp()
  {
    super .setUp()
    
    // Create a couple of test packages that can be relied on during a test
    createTestPackage(from: "https://github.com/vapor/vapor.git")
    createTestPackage(from: "https://github.com/Alamofire/Alamofire.git")
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
    XCTAssertThrowsError(try Package.findByUrl(on: database, url: nonExistentUrl).wait()) { error in
      XCTAssertEqual(error as? PackageError, PackageError.recordNotFound)
    }
  }
}
