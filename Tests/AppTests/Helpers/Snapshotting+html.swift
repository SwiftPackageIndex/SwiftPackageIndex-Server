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

import Plot
import SnapshotTesting
import Dependencies


extension Snapshotting where Value == String, Format == String {
    public static var html: Snapshotting<String, String> {
        Snapshotting(pathExtension: "html", diffing: .lines)
    }
}


extension Snapshotting where Value == () -> HTML, Format == String {
    public static var html: Snapshotting {
        Snapshotting<String, String>.init(pathExtension: "html", diffing: .lines).pullback { node in
            withDependencies {
                $0.environment.siteURL = { "http://localhost:8080" }
            } operation: {
                return node().render(indentedBy: .spaces(2))
            }
        }
    }
}


extension Snapshotting where Value == () -> Node<HTML.BodyContext>, Format == String {
    public static var html: Snapshotting {
        Snapshotting<() -> HTML, String>.html.pullback { node in
            { HTML(.body(node())) }
        }
    }
}
