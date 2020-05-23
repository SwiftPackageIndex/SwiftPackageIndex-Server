@testable import App

import Foundation
import XCTest


class RelativeDateTimeFormatterTests: XCTestCase {

    func test_basic() throws {
        let oneDay: TimeInterval = 86400
        let now = Date()
        let yesterday = now.addingTimeInterval(-oneDay)
        let twoDaysAgo = now.addingTimeInterval(-2*oneDay)

        let formatter = _RelativeDateTimeFormatter()
        XCTAssertEqual(formatter.localizedString(for: now, relativeTo: now), "in 0 seconds")
        XCTAssertEqual(formatter.localizedString(for: now.addingTimeInterval(-5),
                                                 relativeTo: now), "less than a minute ago")
        XCTAssertEqual(formatter.localizedString(for: now.addingTimeInterval(-30),
                                                 relativeTo: now), "1 minute ago")
        XCTAssertEqual(formatter.localizedString(for: now.addingTimeInterval(-60),
                                                 relativeTo: now), "1 minute ago")
        XCTAssertEqual(formatter.localizedString(for: now.addingTimeInterval(-90),
                                                 relativeTo: now), "1 minute ago")
        XCTAssertEqual(formatter.localizedString(for: yesterday, relativeTo: now), "1 day ago")
        XCTAssertEqual(formatter.localizedString(for: twoDaysAgo, relativeTo: now), "2 days ago")
    }

}
