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


extension [Version] {
    var defaultBranchVersion: Version? { filter { $0.latest == .defaultBranch}.first }
    var preReleaseVersion: Version? { filter { $0.latest == .preRelease}.first }
    var releaseVersion: Version? { filter { $0.latest == .release}.first }

    func canonicalDocumentationTarget() -> DocumentationTarget? {
        // External documentation links have priority over generated documentation.
        if let spiManifest = defaultBranchVersion?.spiManifest,
           let documentation = spiManifest.externalLinks?.documentation {
            return .external(url: documentation)
        }

        // Ideal case is that we have a stable release documentation.
        if let version = releaseVersion,
           let archive = version.docArchives?.first?.name {
            return .internal(reference: .reference("\(version.reference)"), archive: archive)
        }

        // Then a pre-release is second best.
        if let version = preReleaseVersion,
           let archive = version.docArchives?.first?.name {
            return .internal(reference: .reference("\(version.reference)"), archive: archive)
        }

        // Finally, fallback to the default branch documentation.
        if let version = defaultBranchVersion,
           let archive = version.docArchives?.first?.name {
            return .internal(reference: .reference("\(version.reference)"), archive: archive)
        }

        // There is no default dodcumentation.
        return nil
    }

    func hasDocumentation() -> Bool { canonicalDocumentationTarget() != nil }
}


extension [Version?] {
    func canonicalDocumentationTarget() -> DocumentationTarget? {
        self.compactMap { $0 }.canonicalDocumentationTarget()
    }

    func hasDocumentation() -> Bool { compactMap { $0 }.hasDocumentation() }
}
