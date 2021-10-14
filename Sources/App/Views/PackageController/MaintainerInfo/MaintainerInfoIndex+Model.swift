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
import Plot


extension MaintainerInfoIndex {
    // TODO: find original query and redefine or re-use type there
    typealias PackageResult = PackageController.PackageResult

    struct Model {
        var packageName: String
        var repositoryOwner: String
        var repositoryName: String

        init?(result: PackageResult) {
            guard let packageName = result.versions.packageName(),
                  let repositoryOwner = result.repository?.owner,
                  let repositoryName = result.repository?.name else { return nil }

            self.init(packageName: packageName, repositoryOwner: repositoryOwner, repositoryName: repositoryName)
        }

        internal init(packageName: String, repositoryOwner: String, repositoryName: String) {
            self.packageName = packageName
            self.repositoryOwner = repositoryOwner
            self.repositoryName = repositoryName
        }

        func badgeURL(for type: PackageResult.BadgeType) -> String {
            let characterSet = CharacterSet.urlHostAllowed.subtracting(.init(charactersIn: "=:"))
            let url = SiteURL.api(.packages(.value(repositoryOwner), .value(repositoryName), .badge)).absoluteURL(parameters: [QueryParameter(key: "type", value: type.rawValue)])
            let escaped = url.addingPercentEncoding(withAllowedCharacters: characterSet) ?? url
            return "https://img.shields.io/endpoint?url=\(escaped)"
        }

        func badgeMarkdown(for type: PackageResult.BadgeType) -> String {
            let spiPackageURL = SiteURL.package(.value(repositoryOwner), .value(repositoryName), .none).absoluteURL()
            return "[![](\(badgeURL(for: type)))](\(spiPackageURL))"
        }

        func badgeMarkdowDisplay(for type: PackageResult.BadgeType) -> Node<HTML.FormContext> {
            .input(
                .type(.text),
                .value(badgeMarkdown(for: type)),
                .data(named: "button-name", value: "Copy Markdown"),
                .data(named: "event-name", value: "Copy Markdown Button"),
                .readonly(true)
            )
        }
    }
}
