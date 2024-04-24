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


struct DocRoute {
    var owner: String
    var repository: String
    var docVersion: DocVersion
    var fragment: Fragment
    var pathElements: [String] = []

    var contentType: String { fragment.contentType }

    enum DocVersion: CustomStringConvertible {
        case current(referencing: String)
        case reference(String)

        var description: String {
            switch self {
                case .current:
                    return "~"
                case .reference(let string):
                    return string
            }
        }

        var reference: String {
            switch self {
                case .current(let reference):
                    return reference
                case .reference(let reference):
                    return reference
            }
        }
    }

    enum Fragment: String, CustomStringConvertible {
        case css
        case data
        case documentation
        case faviconIco = "favicon.ico"
        case faviconSvg = "favicon.svg"
        case images
        case img
        case index
        case js
        case linkablePaths = "linkable-paths.json"
        case themeSettings = "theme-settings.json"
        case tutorials

        var contentType: String {
            switch self {
                case .css:
                    return "text/css"
                case .data, .faviconIco, .faviconSvg, .images, .img, .index:
                    return "application/octet-stream"
                case .linkablePaths, .themeSettings:
                    return "application/json"
                case .documentation, .tutorials:
                    return "text/html; charset=utf-8"
                case .js:
                    return "application/javascript"
            }
        }

        var requiresArchive: Bool {
            switch self {
                case .css, .data, .faviconIco, .faviconSvg, .images, .img, .index, .js, .linkablePaths, .themeSettings, .tutorials:
                    return false
                case .documentation:
                    return true
            }
        }

        var description: String { rawValue }
    }
}

extension DocRoute {
    var baseURL: String { "\(owner.lowercased())/\(repository.lowercased())/\(docVersion.reference.pathEncoded.lowercased())" }

    var archive: String? { pathElements.first }

    var path: String { pathElements.joined(separator: "/") }
}
