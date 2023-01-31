import XCTest


func XCTUnwrapAsync<T>(_ expression: @autoclosure () async throws -> T?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) async throws -> T {
    let res = try await expression()
    return try XCTUnwrap(res, message())
}
