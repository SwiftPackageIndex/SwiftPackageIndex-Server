import XCTest
import Synchronization


private let count = Mutex(0)

class ParallelXCTest: XCTestCase {

    func test_0() async throws {
        count.increment()
        defer { count.decrement() }
        print("⚠️ count: \(count.value)")
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(count.value, 0)
    }
    func test_1() async throws {
        count.increment()
        defer { count.decrement() }
        print("⚠️ count: \(count.value)")
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(count.value, 0)
    }
    func test_2() async throws {
        count.increment()
        defer { count.decrement() }
        print("⚠️ count: \(count.value)")
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(count.value, 0)
    }
    func test_3() async throws {
        count.increment()
        defer { count.decrement() }
        print("⚠️ count: \(count.value)")
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(count.value, 0)
    }
    func test_4() async throws {
        count.increment()
        defer { count.decrement() }
        print("⚠️ count: \(count.value)")
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(count.value, 0)
    }

}


private extension Mutex where Value == Int {
    func increment() { self.withLock { $0 += 1 } }
    func decrement() { self.withLock { $0 -= 1 } }
    var value: Int { self.withLock{ $0 } }
}
