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

import XCTest

@testable import App

import SPIManifest


final class ValidateSPIManifestControllerTests: XCTestCase {

    func test_validationResult_basic() throws {
        let yml = ValidateSPIManifest.Model.placeholderManifest

        // MUT
        let res = ValidateSPIManifestController.validationResult(manifest: yml)

        // validate
        XCTAssertEqual(res, .valid(try SPIManifest.Manifest(yml: yml)))
    }

    func test_validationResult_decodingError() throws {
        let yml = """
            broken:
            """

        // MUT
        let res = ValidateSPIManifestController.validationResult(manifest: yml)

        // validate
        XCTAssertEqual(res, .invalid("Decoding failed: Key not found: 'version'."))
    }

    func test_validationResult_tooLarge() throws {
        let targets = (0..<200).map { "Target_\($0)" }.joined(separator: ", ")
        let yml = """
            version: 1
            builder:
              configs:
                - documentation_targets: [\(targets)]
            """
        XCTAssert(yml.count > SPIManifest.Manifest.maxByteSize)

        // MUT
        let res = ValidateSPIManifestController.validationResult(manifest: yml)

        // validate
        XCTAssertEqual(res.isValid, false)
        XCTAssertEqual(res, .invalid("File must not exceed \(SPIManifest.Manifest.maxByteSize) bytes. File size: \(yml.count) bytes."))
    }

}
