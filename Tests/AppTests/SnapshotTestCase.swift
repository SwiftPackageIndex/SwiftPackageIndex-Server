// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

class SnapshotTestCase: AppTestCase {

    override func setUp() {
        super.setUp()

        Current.date = { Date(timeIntervalSince1970: 0) }

        SnapshotTesting.isRecording = false
        SnapshotTesting.diffTool = "ksdiff"
    }
}
