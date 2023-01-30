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

import Vapor
import Plot

extension ErrorPage {

    struct Model {
        let error: AbortError

        init(_ error: AbortError) {
            self.error = error
        }

        var errorMessage: String {
            get {
                var message = "\(error.status.code) - \(error.status.reasonPhrase)"
                if error.reason != error.status.reasonPhrase {
                    message += " - \(error.reason)"
                }
                return message
            }
        }

        var errorInstructions: Node<HTML.BodyContext> {
            get {
                switch error.status.code {
                    case 404:
                        return .p(
                            .text("If you were expecting to find a page here, please "),
                            .a(
                                .href(ExternalURL.raiseNewIssue),
                                "raise an issue"
                            ),
                            .text(".")
                        )
                    default:
                        return .empty
                }
            }
        }
    }

}
