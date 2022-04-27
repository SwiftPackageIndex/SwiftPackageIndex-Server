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
import SwiftSoup

// Note for PR: I'm not sure of the best place to put a utility like this
// but it needs extracting now so that Plot and SwiftSoup don't constantly
// fight over their different definitions of Node and Element.
// It's in Core for now, but we can move it.

struct DocumentationPageProcessor {
    let document: Document

    init?(rawHtml: String) {
        do {
            document = try SwiftSoup.parse(rawHtml)
        } catch {
            return nil
        }
    }

    var processedPage: String {
        do {
            return try document.html()
        } catch {
            return "An error occurred while rendering processed documentation."
        }
    }
}
