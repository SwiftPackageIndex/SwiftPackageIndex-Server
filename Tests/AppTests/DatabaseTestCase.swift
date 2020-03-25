import Vapor
import FluentPostgreSQL
import XCTest

@testable import App

class DatabaseTestCase: XCTestCase
{
  var app: Application!
  var database: PostgreSQLConnection!

  override func setUp()
  {
    super .setUp()

    try! Application.reset()
    app = try! Application.testable()
    database = try! app.newConnection(to: .psql).wait()
  }

  override func tearDown()
  {
    super .tearDown()
    
    database.close()
    try? app.syncShutdownGracefully()
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
}
