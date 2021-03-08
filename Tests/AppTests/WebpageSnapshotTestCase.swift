@testable import App

import XCTVapor


class WebpageSnapshotTestCase: SnapshotTestCase {
    let defaultPrecision: Float = 1

    override func setUpWithError() throws {
        try super.setUpWithError()

        try XCTSkipIf((Environment.get("SKIP_SNAPSHOTS") ?? "false") == "true")
        Current.date = { Date(timeIntervalSince1970: 0) }
        TempWebRoot.cleanup()
    }

    override class func setUp() {
        TempWebRoot.setup()
    }
}
