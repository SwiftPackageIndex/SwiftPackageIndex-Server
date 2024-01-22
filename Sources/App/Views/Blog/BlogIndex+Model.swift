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

import Foundation
import Yams

enum BlogIndex {

    struct Model {

        struct PostSummary {
            var title: String
            var postUrl: String
            var postedAt: Date
            var summary: String
        }

        var summaries: [PostSummary]

        init() {
            summaries = []
        }

        func markdownFilePaths() -> [String]? {
            let pathToPosts = Current.fileManager.workingDirectory()
                .appending("Resources/Blog/Posts/")
            do {
                return try Current.fileManager.contentsOfDirectory(atPath: pathToPosts)
                    .filter { $0.hasSuffix(".md") }
            } catch {
                return nil
            }
        }
    }
}
