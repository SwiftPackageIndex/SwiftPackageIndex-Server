import XCTest

@testable import AppTests

XCTMain([
  testCase(PackageListReconcilerTests.allTests),
  testCase(PackageTests.allTests)
])
