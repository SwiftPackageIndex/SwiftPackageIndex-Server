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

extension PackageShow {

    struct PackageSchema: Encodable {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case identifier, name, description, license, version,
                 codeRepository, url, datePublished, dateModified,
                 sourceOrganization, programmingLanguage, keywords
        }

        var context: String = "https://schema.org"
        var type: String = "SoftwareSourceCode"

        let identifier: String
        let name: String
        let description: String?
        let license: String?
        let version: String?
        let codeRepository: String
        let url: String
        let datePublished: Date?
        let dateModified: Date?
        let sourceOrganization: OrganisationSchema
        let programmingLanguage: ComputerLanguageSchema
        let keywords: [String]

        init(
            repositoryOwner: String,
            repositoryName: String,
            organisationName: String?,
            summary: String?,
            licenseUrl: String?,
            version: String?,
            repositoryUrl: String,
            datePublished: Date?,
            dateModified: Date?,
            keywords: [String]
        ) {
            self.identifier = "\(repositoryOwner)/\(repositoryName)"
            self.name = repositoryName
            self.description = summary
            self.license = licenseUrl
            self.version = version
            self.codeRepository = repositoryUrl
            self.url = SiteURL.package(.value(repositoryOwner), .value(repositoryName), .none).absoluteURL()
            self.datePublished = datePublished
            self.dateModified = dateModified
            self.sourceOrganization = OrganisationSchema(legalName: organisationName ?? repositoryOwner)
            self.programmingLanguage = ComputerLanguageSchema(name: "Swift", url: "https://swift.org/")
            self.keywords = keywords
        }

        init?(result: PackageController.PackageResult) {
            let package = result.package
            let repository = result.repository
            guard
                let repositoryOwner = repository.owner,
                let repositoryName = repository.name
            else {
                return nil
            }

            self.init(
                repositoryOwner: repositoryOwner,
                repositoryName: repositoryName,
                organisationName: repository.ownerName,
                summary: repository.summary,
                licenseUrl: repository.licenseUrl,
                version: PackageShow.releaseInfo(
                    packageUrl: package.url,
                    defaultBranchVersion: result.defaultBranchVersion,
                    releaseVersion: result.releaseVersion,
                    preReleaseVersion: result.preReleaseVersion).stable?.link.label,
                repositoryUrl: package.url.droppingGitExtension,
                datePublished: repository.firstCommitDate,
                dateModified: repository.lastActivityAt,
                keywords: repository.keywords
            )
        }

        var publicationDates: (datePublished: Date, dateModified: Date)? {
            guard let datePublished = datePublished, let dateModified = dateModified
            else { return nil }
            return (datePublished, dateModified)
        }
    }

    struct OrganisationSchema: Encodable {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case legalName
        }

        var context: String = "https://schema.org"
        var type: String = "Organization"

        let legalName: String

        init(legalName: String) {
            self.legalName = legalName
        }
    }

    struct ComputerLanguageSchema: Encodable {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case name, url
        }

        var context: String = "https://schema.org"
        var type: String = "ComputerLanguage"

        let name: String
        let url: String

        init(name: String, url: String) {
            self.name = name
            self.url = url
        }
    }
}


extension PackageShow {
    @available(*, deprecated)
    static func releaseInfo(packageUrl: String,
                            defaultBranchVersion: DefaultVersion?,
                            releaseVersion: ReleaseVersion?,
                            preReleaseVersion: PreReleaseVersion?) -> PackageShow.Model.ReleaseInfo {
        let links = [releaseVersion?.model, preReleaseVersion?.model, defaultBranchVersion?.model]
            .map { version -> DatedLink? in
                guard let version = version else { return nil }
                return makeDatedLink(packageUrl: packageUrl,
                                     version: version,
                                     keyPath: \.commitDate)
            }
        return .init(stable: links[0],
                     beta: links[1],
                     latest: links[2])
    }
}
