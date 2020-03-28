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

    let fakeClient = try app.make(FakeClient.self)
    let fakePackageList = [ "https://github.com/vapor/vapor.git", "https://github.com/zntfdr/AStack.git" ]
    fakeClient.registerClientResponse(for: "https://raw.githubusercontent.com/daveverwer/SwiftPMLibrary/master/packages.json", content: fakePackageList)

    let command = ReconcilePackageListCommand()
    let commandContext = CommandContext(console: Terminal(), arguments: [:], options: [:], on: app)
    try command.run(using: commandContext).wait()

    // Validate that the database contains exactly the number of packages in the faked package list
    let countAfterReconcile = try Package.query(on: database).count().wait()
    XCTAssertEqual(countAfterReconcile, fakePackageList.count)

    // Validate that the database contains every package in the faked package list
    for packageUrlString in fakePackageList {
      let packageUrl = URL(string: packageUrlString)!
      let package = try Package.findByUrl(on: database, url: packageUrl).wait()
      XCTAssertEqual(package.url, packageUrl)
    }
  }
}
