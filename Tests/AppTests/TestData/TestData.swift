// swiftlint:disable force_try

import DatabaseKit

@testable import App

class TestData {
  /// Helper method to create a test Package in the database.
  /// - Parameters:
  ///   - database: A database connection to use for creating the test package.
  ///   - url: A string containing a valid package URL.
  static func createPackage(on database: DatabaseConnectable, urlString: String) {
    guard let url = URL(string: urlString)
      else { preconditionFailure("Expected a valid URL") }
    let package = Package(url: url)
    _ = try! package.create(on: database).wait()
  }
}
