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
import SPIManifest


enum ValidateSPIManifestController {

    static func show(req: Request) async throws -> HTML {
        let model = ValidateSPIManifest.Model()
        return ValidateSPIManifest.View(path: req.url.path, model: model).document()
    }

    static func validate(req: Request) async throws -> HTML {
        struct FormData: Content {
            var manifest: String
        }

        let formData = try req.content.decode(FormData.self)
        let validationResult = validationResult(manifest: formData.manifest)
        let model = ValidateSPIManifest.Model(manifest: formData.manifest, validationResult: validationResult)
        return ValidateSPIManifest.View(path: req.url.path, model: model).document()
    }

    static func validationResult(manifest: String) -> ValidateSPIManifest.ValidationResult {
        do {
            return .valid(try SPIManifest.Manifest(yml: manifest))
        } catch let error as DecodingError {
            return .invalid("\(error)")
        } catch {
            return .invalid(error.localizedDescription)
        }
    }
}
