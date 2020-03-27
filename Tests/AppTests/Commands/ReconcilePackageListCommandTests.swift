import Vapor
import FluentPostgreSQL
import XCTest

@testable import App

final class ReconcilePackageListCommandTests: XCTestCase
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

  func testAddingAndDeletingPackages() throws
  {
    TestData.createPackage(on:database, urlString: "https://github.com/Alamofire/Alamofire.git")
    TestData.createPackage(on:database, urlString: "https://github.com/vapor/vapor.git")

    let fakeClient = app.fakeClient

    let countBeforeReconcile = try Package.query(on: database).count().wait()
    XCTAssertEqual(countBeforeReconcile, 2)

    let command = ReconcilePackageListCommand()
    let commandContext = CommandContext(console: Terminal(), arguments: [:], options: [:], on: app)
    try command.run(using: commandContext).wait()

    let countAfterReconcile = try Package.query(on: database).count().wait()
    XCTAssertEqual(countAfterReconcile, 2)
  }
}
