import SnapshotTesting


class SnapshotTestCase: AppTestCase {

    override class func setUp() {
        super.setUp()

        SnapshotTesting.isRecording = false
        SnapshotTesting.diffTool = "ksdiff"
    }
}
