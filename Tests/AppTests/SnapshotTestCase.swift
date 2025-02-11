// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import App

import Foundation
import SnapshotTesting
import Dependencies


class SnapshotTestCase: ParallelizedAppTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
    }
    
    override func invokeTest() {
        // To force a re-record of all snapshots, use `record: .all` rather than `record: .missing`.
        withSnapshotTesting(record: .missing, diffTool: .ksdiff) {
            withDependencies {
                $0.date.now = .t0
            } operation: {
                super.invokeTest()
            }
        }
    }

}
