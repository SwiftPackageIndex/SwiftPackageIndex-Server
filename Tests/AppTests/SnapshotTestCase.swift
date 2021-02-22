import SnapshotTesting


class SnapshotTestCase: AppTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()

        SnapshotTesting.isRecording = false
        SnapshotTesting.diffTool = "ksdiff"
    }
}
