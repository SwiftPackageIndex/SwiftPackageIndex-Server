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

import Plot

enum ValidateSPIManifest {
    struct Model {
        var manifest: String = Self.placeholderManifest
        var validationResult: ValidationResult?

        static let placeholderManifest = """
            version: 1
            builder:
              configs:
                - documentation_targets: [Target1, Target2]
            """
    }

    struct ValidationResult {
        var isValid: Bool
        var message: String

        var cssClass: String {
            isValid ? "valid" : "invalid"
        }
    }
}
