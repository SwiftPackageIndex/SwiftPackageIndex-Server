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

import SPIManifest
import Testing


extension AllTests.ValidateSPIManifestControllerTests {

    @Test func validationResult_basic() throws {
        let yml = ValidateSPIManifest.Model.placeholderManifest

        // MUT
        let res = ValidateSPIManifestController.validationResult(manifest: yml)

        // validate
        #expect(try res == .valid(SPIManifest.Manifest(yml: yml)))
    }

    @Test func validationResult_decodingError() throws {
        let yml = """
            broken:
            """

        // MUT
        let res = ValidateSPIManifestController.validationResult(manifest: yml)

        // validate
        #expect(res == .invalid("Decoding failed: Key not found: 'version'."))
    }

    @Test func validationResult_tooLarge() throws {
        let targets = (0..<200).map { "Target_\($0)" }.joined(separator: ", ")
        let yml = """
            version: 1
            builder:
              configs:
                - documentation_targets: [\(targets)]
            """
        #expect(yml.count > SPIManifest.Manifest.maxByteSize)

        // MUT
        let res = ValidateSPIManifestController.validationResult(manifest: yml)

        // validate
        #expect(res == .invalid("File must not exceed \(SPIManifest.Manifest.maxByteSize) bytes. File size: \(yml.count) bytes."))
    }

}
