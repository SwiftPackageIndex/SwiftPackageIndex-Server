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

import Foundation
import Plot

extension BuildMonitorIndex {

    struct Model {
        var buildId: UUID
        let createdAt: Date = Date()
        let packageName: String = "LeftPad"
        let repositoryOwner: String = "daveverwer"
        let repositoryName: String = "LeftPad"
        let branchOrVersion: String = "main"
        let platform: String = "Linux"
        let swiftVersion: String = "5.5"
        let buildMachine: String = "Mac 1"

        func buildMonitorListItem() -> Node<HTML.ListContext> {
            .li(
                .p(.text(packageName))
            )
        }
    }
}
