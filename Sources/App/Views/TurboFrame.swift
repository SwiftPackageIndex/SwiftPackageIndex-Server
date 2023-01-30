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
import Vapor
import Plot

class TurboFrame {

    /// The frame's full HTML content.
    /// - Returns: A <turbo-frame> element that will be rendered by Turbo.
    final func document() -> Node<HTML.BodyContext> {
        .turboFrame(id: frameIdentifier(), frameContent())
    }

    /// The identifier targeting which turbo frame should be replaced.
    /// - Returns: A string containing the identifier.
    func frameIdentifier() -> String {
        ""
    }

    /// The page content.
    /// - Returns: The node(s) that make up the frame's content.
    func frameContent() -> Node<HTML.BodyContext> {
        .empty
    }

}
