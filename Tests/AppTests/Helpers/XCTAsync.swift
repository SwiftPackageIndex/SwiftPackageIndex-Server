import XCTest


func XCTUnwrapAsync<T>(_ expression: @autoclosure () async throws -> T?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) async throws -> T {
    let res = try await expression()
    return try XCTUnwrap(res, message(), file: file, line: line)
}


public func XCTAssertEqualAsync<T>(_ expression1: @autoclosure () async throws -> T, _ expression2: @autoclosure () async throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) async throws where T : Equatable {
    let exp1 = try await expression1()
    let exp2 = try await expression2()
    XCTAssertEqual(exp1, exp2, message(), file: file, line: line)
}


public func XCTAssertNoThrowAsync<T>(_ expression: @autoclosure () async throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) async throws {
    let res = try await expression()
    try XCTAssertNoThrow(res, message(), file: file, line: line)
}
